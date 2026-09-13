import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/theme/theme_cubit.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/data/services/demo_seeder.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/stats/cubit/stats_cubit.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NumberFormat _fmt = NumberFormat('#,##0.##', 'ar');

  bool _biometricEnabled = false;
  bool _dailyReminderEnabled = true;
  bool _smsAutoImportEnabled = true;
  double _lowBalanceThreshold = 10000.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
      _dailyReminderEnabled = prefs.getBool('dailyReminderEnabled') ?? true;
      _smsAutoImportEnabled = prefs.getBool('smsAutoImportEnabled') ?? true;
      _lowBalanceThreshold = prefs.getDouble('lowBalanceThreshold') ?? 10000.0;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final bioService = BiometricService();
      final canCheck = await bioService.isBiometricsAvailable();
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جهازك لا يدعم المصادقة بالبصمة أو لم يتم إعدادها بعد'),
            ),
          );
        }
        return;
      }
      final authenticated = await bioService.authenticate();
      if (!authenticated) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', value);
    setState(() => _biometricEnabled = value);
  }

  Future<void> _toggleDailyReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminderEnabled', value);
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
  }

  Future<void> _toggleSmsAutoImport(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smsAutoImportEnabled', value);
    setState(() => _smsAutoImportEnabled = value);
  }

  Future<void> _editThresholdDialog() async {
    final controller = TextEditingController(text: _lowBalanceThreshold.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حد الرصيد المنخفض'),
        content: Column(
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
                prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المرسلون المعتمدون المدعومون حالياً:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ...SmsSenderRegistry.defaultTemplates.map((tpl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${tpl.walletNameAr}: ${tpl.senderIds.join(', ')}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(),
              const Text(
                'نظام ميزان يتعرف تلقائياً على رسائل الإيداع والخصم والسداد بدقة تامة.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
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

  Future<void> _seedDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('تعبئة بيانات تجريبية'),
          ],
        ),
        content: const Text(
          'سيتم إنشاء 3 محافظ يمنية (الكريمي، جيب، كاش) وإضافة 20 حركة تجريبية واقعية موزعة على آخر 30 يوماً لعرض التقارير والإحصائيات بدقة.\n\nهل تود المتابعة؟',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التعبئة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await DemoDataSeeder.seedDemoData(
          walletRepository: WalletRepository(),
          transactionRepository: TransactionRepository(),
        );

        if (mounted) {
          context.read<WalletsCubit>().loadWallets();
          context.read<TransactionsCubit>().loadTransactions();
          context.read<StatsCubit>().loadStats();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text('تمت تعبئة 3 محافظ و 20 حركة تجريبية بنجاح! 🚀'),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء التعبئة: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthCubit>().signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isEmbedded
        ? _buildContent()
        : Scaffold(
            appBar: AppBar(
              title: const Text('الإعدادات'),
              centerTitle: true,
            ),
            body: _buildContent(),
          );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      children: [
        // Section 1: Appearance & Theme
        _buildSectionHeader('المظهر والعرض'),
        _buildCard([
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppTheme.primaryColor),
                title: const Text('مظهر التطبيق'),
                subtitle: Text(
                  themeMode == ThemeMode.system
                      ? 'تلقائي (حسب النظام)'
                      : (themeMode == ThemeMode.dark ? 'الوضع الليلي 🌙' : 'الوضع الفاتح ☀️'),
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
            secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryColor),
            title: const Text('الدخول بالبصمة'),
            subtitle: const Text(
              'طلب البصمة عند فتح التطبيق لحماية خصوصيتك',
              style: TextStyle(fontSize: 12),
            ),
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
          ),
        ]),
        const SizedBox(height: 16),

        // Section 3: Notifications & Alerts
        _buildSectionHeader('الإشعارات والتنبيهات'),
        _buildCard([
          SwitchListTile(
            activeThumbColor: AppTheme.primaryColor,
            secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryColor),
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
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
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
            SwitchListTile(
              activeThumbColor: AppTheme.primaryColor,
              secondary: const Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryColor),
              title: const Text('الاستيراد التلقائي للرسائل'),
              subtitle: const Text(
                'استيراد حركات المحافظ في الخلفية فور فتح التطبيق',
                style: TextStyle(fontSize: 12),
              ),
              value: _smsAutoImportEnabled,
              onChanged: _toggleSmsAutoImport,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor),
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

        // Section 5: Tools & Demonstrations
        _buildSectionHeader('الأدوات والتجربة'),
        _buildCard([
          ListTile(
            leading: const Icon(Icons.calculate_outlined, color: AppTheme.primaryColor),
            title: const Text('حاسبة عمولات المحافظ'),
            subtitle: const Text(
              'حساب عمولات ورسوم التحويل والسحب بين المحافظ اليمنية',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.pushNamed(context, AppRoutes.commission),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.amber),
            title: const Text('تعبئة بيانات تجريبية (Demo)'),
            subtitle: const Text(
              'إضافة 3 محافظ و 20 حركة تجريبية لعرض تقارير التطبيق',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: _seedDemoData,
          ),
        ]),
        const SizedBox(height: 20),

        // Section 6: Logout
        Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: _logout,
          ),
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

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
