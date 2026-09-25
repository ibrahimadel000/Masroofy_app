import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/theme/theme_cubit.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/data/services/sms_service.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';
import 'package:mizaan/features/auth/screens/login_screen.dart';
import 'package:mizaan/features/auth/screens/register_screen.dart';
import 'package:mizaan/features/home/widgets/app_hints_modal.dart';

class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final NumberFormat _fmt = NumberFormat('#,##0.##', 'ar');

  bool _biometricEnabled = false;
  bool _dailyReminderEnabled = true;
  bool _smsAutoImportEnabled = false;
  bool _smsPermissionGranted = false;
  bool _smsSettingsBusy = false;
  bool _batteryOptimizationExempt = false;
  bool _batterySettingsBusy = false;
  bool _smsNotificationsEnabled = true;
  bool _manualTxNotificationsEnabled = true;
  bool _systemNotificationsGranted = true;
  double _lowBalanceThreshold = 10000.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _checkPermissionStatus();
    _refreshSmsStatus();
    _refreshBatteryOptimizationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSmsStatus();
      _refreshBatteryOptimizationStatus();
      _checkPermissionStatus();
    }
  }

  bool get _smsReceiverReady => _smsPermissionGranted && _smsAutoImportEnabled;

  Future<void> _refreshSmsStatus() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final uid = DatabaseService.currentUserId ?? 'guest';
    final granted = await const SmsService().hasPermission();
    final enabled = SmsService.isAutoImportEnabled(prefs, uid: uid);
    if (!granted && enabled) {
      await SmsService.setAutoImportEnabled(prefs, uid: uid, value: false);
    }
    if (mounted) {
      setState(() {
        _smsPermissionGranted = granted;
        _smsAutoImportEnabled = granted && enabled;
      });
    }
  }

  Future<void> _refreshBatteryOptimizationStatus() async {
    if (!Platform.isAndroid) return;
    final exempt = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() => _batteryOptimizationExempt = exempt);
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid || _batterySettingsBusy) return;
    setState(() => _batterySettingsBusy = true);
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      await _refreshBatteryOptimizationStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.isGranted
                  ? 'تم السماح لميزان بالعمل دون قيود البطارية'
                  : 'لم يتم منح استثناء البطارية. يمكنك تغييره من إعدادات النظام.',
            ),
            action: status.isGranted
                ? null
                : SnackBarAction(
                    label: 'الإعدادات',
                    onPressed: openAppSettings,
                  ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _batterySettingsBusy = false);
    }
  }

  Future<void> _checkPermissionStatus() async {
    final notif = NotificationService();
    final hasPerm = await notif.hasPermission();
    if (mounted) {
      setState(() => _systemNotificationsGranted = hasPerm);
    }
    if (!hasPerm) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final retryPerm = await notif.hasPermission();
        if (retryPerm) {
          setState(() => _systemNotificationsGranted = true);
        }
      }
    }
  }

  String _userKey(String base) {
    final authState = context.read<AuthCubit>().state;
    final uid = (authState is Authenticated && !authState.isGuest)
        ? authState.user?.uid
        : 'guest';
    return '${uid ?? 'guest'}_$base';
  }

  Future<void> _saveSetting(String baseKey, bool value) async {
    final authState = context.read<AuthCubit>().state;
    final uid = (authState is Authenticated && !authState.isGuest)
        ? authState.user?.uid
        : null;
    final dbUid = DatabaseService.currentUserId;
    final prefs = await SharedPreferences.getInstance();

    // Save universally across all possible alias keys so any reader sees the exact same value
    await prefs.setBool(baseKey, value);
    await prefs.setBool('guest_$baseKey', value);
    if (uid != null && uid.isNotEmpty) {
      await prefs.setBool('${uid}_$baseKey', value);
    }
    if (dbUid != null && dbUid.isNotEmpty) {
      await prefs.setBool('${dbUid}_$baseKey', value);
    }
  }

  bool _getSetting(SharedPreferences prefs, String baseKey, bool defaultValue) {
    final authState = context.read<AuthCubit>().state;
    final uid = (authState is Authenticated && !authState.isGuest)
        ? authState.user?.uid
        : null;
    final dbUid = DatabaseService.currentUserId;

    if (uid != null && prefs.containsKey('${uid}_$baseKey')) {
      return prefs.getBool('${uid}_$baseKey')!;
    }
    if (dbUid != null && prefs.containsKey('${dbUid}_$baseKey')) {
      return prefs.getBool('${dbUid}_$baseKey')!;
    }
    if (prefs.containsKey(baseKey)) {
      return prefs.getBool(baseKey)!;
    }
    if (prefs.containsKey('guest_$baseKey')) {
      return prefs.getBool('guest_$baseKey')!;
    }
    return defaultValue;
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = _getSetting(prefs, 'biometricEnabled', false);
      _dailyReminderEnabled = _getSetting(prefs, 'dailyReminderEnabled', true);
      _smsAutoImportEnabled = SmsService.isAutoImportEnabled(
        prefs,
        uid: DatabaseService.currentUserId ?? 'guest',
      );
      _smsNotificationsEnabled = _getSetting(
        prefs,
        'smsNotificationsEnabled',
        true,
      );
      _manualTxNotificationsEnabled = _getSetting(
        prefs,
        'manualTxNotificationsEnabled',
        true,
      );
      _lowBalanceThreshold =
          prefs.getDouble(_userKey('lowBalanceThreshold')) ??
          prefs.getDouble('lowBalanceThreshold') ??
          10000.0;
    });
    await _refreshSmsStatus();
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final bioService = BiometricService();
      final canCheck = await bioService.isBiometricsAvailable();
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'جهازك لا يدعم المصادقة بالبصمة أو لم يتم إعدادها بعد',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      final result = await bioService.authenticateWithDetails(
        localizedReason: 'يرجى تأكيد بصمتك لتفعيل ميزة الدخول بالبصمة',
      );
      if (result != BiometricAuthResult.success) {
        if (mounted) {
          String msg = 'تعذر تفعيل البصمة';
          if (result == BiometricAuthResult.notEnrolled) {
            msg =
                'لم يتم تسجيل بصمة في هذا الجهاز أو المحاكي. يرجى إضافة بصمة من إعدادات النظام أولاً.';
          } else if (result == BiometricAuthResult.lockedOut) {
            msg = 'تم قفل محاولات البصمة مؤقتاً لكثرة المحاولات الخاطئة.';
          } else if (result == BiometricAuthResult.notAvailable) {
            msg = 'المصادقة بالبصمة غير مدعومة على هذا الجهاز.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
          );
        }
        return;
      }
    }

    await _saveSetting('biometricEnabled', value);
    if (mounted) {
      context.read<AuthCubit>().setBiometricEnabled(value);
      setState(() => _biometricEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'تم تفعيل قفل البصمة بنجاح 🛡️' : 'تم تعطيل قفل البصمة',
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleDailyReminder(bool value) async {
    await _saveSetting('dailyReminderEnabled', value);
    setState(() => _dailyReminderEnabled = value);

    final notif = NotificationService();
    if (value) {
      final granted = await notif.requestPermission();
      if (granted) {
        await notif.scheduleDailyReminder();
      }
    } else {
      await notif.cancelDailyReminder();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تم تفعيل التذكير اليومي (9:00 مساءً) ⏰'
                : 'تم تعطيل التذكير اليومي',
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleSmsAutoImport(bool value) async {
    if (_smsSettingsBusy || !Platform.isAndroid) return;
    setState(() => _smsSettingsBusy = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = DatabaseService.currentUserId ?? 'guest';

      if (!value) {
        await SmsService.setAutoImportEnabled(prefs, uid: uid, value: false);
        if (mounted) {
          setState(() {
            _smsAutoImportEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إيقاف استقبال واستيراد رسائل SMS'),
            ),
          );
        }
        return;
      }

      final granted = await const SmsService().requestPermission();
      if (granted) {
        await SmsService.setAutoImportEnabled(prefs, uid: uid, value: true);
        if (mounted) {
          setState(() {
            _smsPermissionGranted = true;
            _smsAutoImportEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم تفعيل استقبال الرسائل والاستيراد التلقائي بنجاح',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      } else {
        await SmsService.setAutoImportEnabled(prefs, uid: uid, value: false);
        final permanentlyDenied = await Permission.sms.isPermanentlyDenied;
        if (mounted) {
          setState(() {
            _smsPermissionGranted = false;
            _smsAutoImportEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                permanentlyDenied
                    ? 'صلاحية SMS محظورة. افتح إعدادات التطبيق واسمح بالرسائل.'
                    : 'لم يتم منح صلاحية SMS، لذلك لم يتم تفعيل المزامنة.',
              ),
              action: permanentlyDenied
                  ? SnackBarAction(
                      label: 'فتح الإعدادات',
                      onPressed: openAppSettings,
                    )
                  : null,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _smsSettingsBusy = false);
    }
  }

  Future<void> _toggleSmsNotifications(bool value) async {
    await _saveSetting('smsNotificationsEnabled', value);
    setState(() => _smsNotificationsEnabled = value);
    if (value) {
      final notif = NotificationService();
      final hasPerm = await notif.hasPermission();
      if (!hasPerm) {
        await notif.requestPermission();
        _checkPermissionStatus();
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تم تفعيل إشعارات حركات الرسائل (SMS) 🔔'
                : 'تم تعطيل إشعارات حركات الرسائل (SMS)',
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _requestSmsReceiverActivation() async {
    await _toggleSmsAutoImport(!_smsReceiverReady);
  }

  Future<void> _toggleManualTxNotifications(bool value) async {
    await _saveSetting('manualTxNotificationsEnabled', value);
    setState(() => _manualTxNotificationsEnabled = value);
    if (value) {
      final notif = NotificationService();
      final hasPerm = await notif.hasPermission();
      if (!hasPerm) {
        await notif.requestPermission();
        _checkPermissionStatus();
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تم تفعيل إشعارات العمليات المالية 🔔'
                : 'تم تعطيل إشعارات العمليات المالية',
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editThresholdDialog() async {
    final controller = TextEditingController(
      text: _lowBalanceThreshold.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حد الرصيد المنخفض'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل المبلغ بالريال اليمني الذي إذا نقص رصيد أي محفظة عنه يتم تنبيهك فوراً:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.ي)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_userKey('lowBalanceThreshold'), result);
      await prefs.setDouble('lowBalanceThreshold', result);
      setState(() => _lowBalanceThreshold = result);
    }
  }

  Future<void> _showSmsSendersDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_chat_read_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('مرسلو رسائل المحافظ'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المرسلون المعتمدون المدعومون حالياً:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...SmsSenderRegistry.defaultTemplates.map(
                  (tpl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${tpl.walletNameAr}: ${tpl.senderIds.join(', ')}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                const Text(
                  'نظام ميزان يتعرف تلقائياً على رسائل الإيداع والخصم والسداد بدقة تامة.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final authState = context.read<AuthCubit>().state;
    final isGuest = authState is Authenticated && authState.isGuest;

    if (isGuest) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: AppTheme.primaryColor,
                size: 26,
              ),
              SizedBox(width: 8),
              Text('إدارة الحساب المحلي', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: const Text(
            'أنت تستخدم التطبيق في الوضع المحلي (خزينة خاصة على هذا الهاتف فقط).\n\nلحفظ سجلاتك والوصول إليها من أي جهاز آخر، يُنصح بربط حسابك بالسحابة أولاً (سيتم ترحيل كافة سجلاتك الحالية).\n\nإذا رغبت في مسح البيانات، سيتم حذف كافة المحافظ والعمليات من هذا الهاتف والبدء من جديد.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
              onPressed: () => Navigator.pop(ctx, 'reset'),
              child: const Text('مسح البيانات والبدء من جديد'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text('ترقية وحفظ في السحابة ☁️'),
              onPressed: () => Navigator.pop(ctx, 'register'),
            ),
          ],
        ),
      );

      if (choice == 'register' && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
        return;
      }

      if (choice == 'reset' && mounted) {
        await context.read<AuthCubit>().resetLocalData();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
        }
        return;
      }

      return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('تسجيل الخروج'),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'تسجيل خروج',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (mounted) {
        await context.read<AuthCubit>().signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isEmbedded
        ? _buildContent()
        : Scaffold(
            appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
            body: _buildContent(),
          );
  }

  Widget _buildContent() {
    return ResponsiveConstraint(
      maxWidth: 750,
      alignment: Alignment.topCenter,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
          // Section 0: Account Status / Link Profile
          _buildAccountCard(),

          // Section 1: Appearance & Theme
          _buildSectionHeader('المظهر والعرض'),
          _buildCard([
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return ListTile(
                  leading: const Icon(
                    Icons.palette_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text('مظهر التطبيق'),
                  subtitle: Text(
                    themeMode == ThemeMode.system
                        ? 'تلقائي (حسب النظام)'
                        : (themeMode == ThemeMode.dark
                              ? 'الوضع الليلي 🌙'
                              : 'الوضع الفاتح ☀️'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('النظام'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('فاتح'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('ليلي'),
                      ),
                    ],
                    onChanged: (newMode) {
                      if (newMode != null) {
                        context.read<ThemeCubit>().setThemeMode(newMode);
                      }
                    },
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Section 2: Security & Biometrics
          _buildSectionHeader('الأمان والحماية'),
          _buildCard([
            SwitchListTile(
              activeThumbColor: AppTheme.primaryColor,
              secondary: const Icon(
                Icons.fingerprint_rounded,
                color: AppTheme.primaryColor,
              ),
              title: const Text('قفل التطبيق بالبصمة / Face ID'),
              subtitle: const Text(
                'طلب تأكيد الهوية عند فتح التطبيق أو العودة إليه لحماية بياناتك المالية',
                style: TextStyle(fontSize: 12),
              ),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          ]),
          const SizedBox(height: 16),

          // Section 3: Notifications & Alerts
          _buildSectionHeader('الإشعارات والتنبيهات (شريط الهاتف)'),
          if (!_systemNotificationsGranted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إشعارات الهاتف معطّلة في النظام',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'لتصلك تنبيهات العمليات في شريط الهاتف بالأعلى، يرجى السماح بالإشعارات من إعدادات الهاتف.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await NotificationService().openSettings();
                      await Future.delayed(const Duration(seconds: 1));
                      _checkPermissionStatus();
                    },
                    child: const Text(
                      'فتح الإعدادات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          _buildCard([
            SwitchListTile(
              activeThumbColor: AppTheme.primaryColor,
              secondary: const Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.primaryColor,
              ),
              title: const Text('إشعارات العمليات المالية'),
              subtitle: const Text(
                'تنبيه فوري في شريط الهاتف عند تسجيل أي مصروف أو إيداع يدوياً',
                style: TextStyle(fontSize: 12),
              ),
              value: _manualTxNotificationsEnabled,
              onChanged: _toggleManualTxNotifications,
            ),
            const Divider(height: 1),
            SwitchListTile(
              activeThumbColor: AppTheme.primaryColor,
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text('التذكير اليومي'),
              subtitle: const Text(
                'تذكير في الساعة 9:00 مساءً لتسجيل مصروفات اليوم',
                style: TextStyle(fontSize: 12),
              ),
              value: _dailyReminderEnabled,
              onChanged: _toggleDailyReminder,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
              ),
              title: const Text('تنبيه الرصيد المنخفض'),
              subtitle: Text(
                'التنبيه عندما ينقص رصيد المحفظة عن ${_fmt.format(_lowBalanceThreshold)} ر.ي',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _editThresholdDialog,
            ),
          ]),
          const SizedBox(height: 16),

          // Section 4: SMS Automation (Android only)
          if (Platform.isAndroid) ...[
            _buildSectionHeader('أتمتة الرسائل (SMS)'),
            _buildCard([
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _smsReceiverReady
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _smsReceiverReady
                        ? Colors.green.withValues(alpha: 0.35)
                        : Colors.amber.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _smsReceiverReady
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      color: _smsReceiverReady
                          ? Colors.green.shade700
                          : Colors.amber.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _smsReceiverReady
                                ? 'مزامنة الرسائل جاهزة'
                                : 'خطوة مطلوبة لتسجيل الحركات تلقائياً',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _smsReceiverReady
                                ? 'صلاحية SMS ممنوحة والاستيراد التلقائي يعمل.'
                                : 'فعّل الخيار التالي ثم وافق على صلاحية الرسائل من النظام.',
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                activeThumbColor: AppTheme.primaryColor,
                secondary: _smsSettingsBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _smsReceiverReady
                            ? Icons.mark_email_read_rounded
                            : Icons.mark_email_unread_rounded,
                        color: _smsReceiverReady
                            ? Colors.green
                            : AppTheme.primaryColor,
                      ),
                title: const Text('استقبال وتسجيل رسائل SMS تلقائياً'),
                subtitle: Text(
                  _smsReceiverReady
                      ? 'مفعّل — الرسائل المالية الجديدة ستُسجل وتحدّث الرصيد.'
                      : 'متوقف — اضغط للتفعيل ومنح صلاحية SMS.',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _smsReceiverReady,
                onChanged: _smsSettingsBusy ? null : _toggleSmsAutoImport,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  _smsPermissionGranted
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  color: _smsPermissionGranted ? Colors.green : Colors.amber,
                ),
                title: const Text('صلاحية قراءة واستقبال SMS'),
                subtitle: Text(
                  _smsPermissionGranted
                      ? 'ممنوحة من نظام أندرويد'
                      : 'غير ممنوحة — المزامنة لن تعمل بدونها',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: _smsSettingsBusy
                      ? null
                      : _requestSmsReceiverActivation,
                  child: Text(_smsReceiverReady ? 'إيقاف' : 'تفعيل'),
                ),
                onTap: _smsSettingsBusy ? null : _requestSmsReceiverActivation,
              ),
              const Divider(height: 1),
              ListTile(
                leading: _batterySettingsBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _batteryOptimizationExempt
                            ? Icons.battery_charging_full_rounded
                            : Icons.battery_alert_rounded,
                        color: _batteryOptimizationExempt
                            ? Colors.green
                            : Colors.orange,
                      ),
                title: const Text('العمل في الخلفية'),
                subtitle: Text(
                  _batteryOptimizationExempt
                      ? 'مسموح دون قيود البطارية — مناسب للأجهزة التي تغلق التطبيقات بقوة.'
                      : 'اختياري: فعّله إذا كان هاتفك يؤخر استقبال الحركات عند إغلاق التطبيق.',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: _batterySettingsBusy
                      ? null
                      : _requestBatteryOptimizationExemption,
                  child: Text(_batteryOptimizationExempt ? 'مفعّل' : 'تفعيل'),
                ),
                onTap: _batterySettingsBusy
                    ? null
                    : _requestBatteryOptimizationExemption,
              ),
              const Divider(height: 1),
              SwitchListTile(
                activeThumbColor: AppTheme.primaryColor,
                secondary: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('إشعارات الحركات (SMS)'),
                subtitle: const Text(
                  'تنبيه عند وصول إيداع أو شراء أو خصم مالي',
                  style: TextStyle(fontSize: 12),
                ),
                value: _smsNotificationsEnabled,
                onChanged: _toggleSmsNotifications,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.sync_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('فحص الرسائل الآن'),
                subtitle: const Text(
                  'استيراد الرسائل المالية السابقة ومراجعتها قبل الحفظ',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.pushNamed(context, AppRoutes.smsSync),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('إدارة مرسلي المحافظ'),
                subtitle: const Text(
                  'عرض قائمة مرسلي الرسائل المدعومين',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: _showSmsSendersDialog,
              ),
            ]),
            const SizedBox(height: 16),
          ],

          // Section: Help, Guide & Hints
          _buildSectionHeader('المساعدة والدليل 💡'),
          _buildCard([
            ListTile(
              leading: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.primaryColor,
              ),
              title: const Text('دليل وتلميحات ميزان'),
              subtitle: const Text(
                'تعرف على آلية عمل التطبيق، الخصوصية، وحلول مشاكل الخلفية للأجهزة المختلفة',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => AppHintsModal.show(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.restart_alt_rounded,
                color: AppTheme.secondaryColor,
              ),
              title: const Text('إظهار دليل البداية السريعة في الرئيسية'),
              subtitle: const Text(
                'إعادة تفعيل بطاقة الخطوات الترحيبية في الشاشة الرئيسية',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('dismissed_new_user_guide', false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تمت إعادة إظهار دليل البداية السريعة في الشاشة الرئيسية ✅',
                      ),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Section 5: Logout or Local Vault Reset
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isGuest = state is Authenticated && state.isGuest;
              final titleText = isGuest
                  ? 'إعادة ضبط الحساب المحلي (مسح السجلات)'
                  : 'تسجيل الخروج';
              final subtitleText = isGuest
                  ? 'حذف المحافظ والعمليات من هذا الهاتف والبدء من جديد'
                  : 'الخروج بأمان من حسابك السحابي الحالي';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: ListTile(
                  leading: Icon(
                    isGuest
                        ? Icons.cleaning_services_rounded
                        : Icons.logout_rounded,
                    color: Colors.red.shade700,
                  ),
                  title: Text(
                    titleText,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    subtitleText,
                    style: TextStyle(color: Colors.red.shade400, fontSize: 11),
                  ),
                  onTap: _logout,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // App Version Footer
          Center(
            child: Text(
              'ميزان — الإصدار 1.0.0 (Yemen Wallets Aggregator)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isGuest = state is Authenticated && state.isGuest;
        final user = state is Authenticated ? state.user : null;

        if (isGuest || user == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E293B), // Slate 800
                  Color(0xFF0F172A), // Slate 900
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'الحساب المحلي (خزينة خاصة)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text('🛡️', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'خصوصية تامة 100% — مشفر ومحفوظ على هذا الهاتف',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Security & Privacy Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.greenAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'مشفر محلياً',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.cyanAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'بدون خوادم خارجية',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                const Text(
                  'لحفظ سجلاتك ضد الضياع والوصول إليها من أي جهاز، فعّل المزامنة السحابية (سيتم ترحيل كافة محافظك وسجلاتك الحالية فوراً وبأمان):',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text(
                      'ترقية وتفعيل المزامنة السحابية ☁️',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text(
                      'لديك حساب سحابي بالفعل؟ تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        // Registered user
        return Container(
          margin: const EdgeInsets.only(bottom: 20.0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'مستخدم ميزان',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'متصل بالسحابة (مُؤمّن)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
