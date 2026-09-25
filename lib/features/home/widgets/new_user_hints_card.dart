import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/sms_service.dart';
import 'package:mizaan/features/home/widgets/app_hints_modal.dart';
import 'package:mizaan/features/onboarding/widgets/permission_education_sheet.dart';
import 'package:mizaan/features/wallets/screens/add_wallet_screen.dart';

class NewUserHintsCard extends StatefulWidget {
  final int walletCount;
  final VoidCallback onDismiss;
  final VoidCallback? onPermissionUpdated;

  const NewUserHintsCard({
    super.key,
    required this.walletCount,
    required this.onDismiss,
    this.onPermissionUpdated,
  });

  @override
  State<NewUserHintsCard> createState() => _NewUserHintsCardState();
}

class _NewUserHintsCardState extends State<NewUserHintsCard> {
  bool _isCollapsed = false;
  bool _hasSmsPermission = false;
  bool _autoImportEnabled = false;
  bool _initialScanCompleted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkStatuses();
  }

  Future<void> _checkStatuses() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = DatabaseService.currentUserId ?? 'guest';
      final permission = await const SmsService().hasPermission();
      final enabled = SmsService.isAutoImportEnabled(prefs, uid: uid);
      final scanned = prefs.getBool('${uid}_smsInitialScanCompleted') ?? false;
      if (mounted) {
        setState(() {
          _hasSmsPermission = permission;
          _autoImportEnabled = permission && enabled;
          _initialScanCompleted = scanned;
        });
      }
    } catch (_) {}
  }

  Future<void> _enableAutomaticSync() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var granted = _hasSmsPermission;
      if (!granted) {
        granted = await PermissionEducationSheet.show(
          context,
          type: PermissionEducationType.sms,
        );
      }
      if (!granted) return;

      final prefs = await SharedPreferences.getInstance();
      final uid = DatabaseService.currentUserId ?? 'guest';
      await SmsService.setAutoImportEnabled(prefs, uid: uid, value: true);
      await _checkStatuses();
      widget.onPermissionUpdated?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مزامنة SMS أصبحت جاهزة لتسجيل الحركات تلقائياً'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _completedStepsCount {
    var count = 0;
    if (_hasSmsPermission) count++;
    if (_autoImportEnabled) count++;
    if (widget.walletCount > 0) count++;
    if (_initialScanCompleted) count++;
    return count;
  }

  static const int _totalSteps = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _completedStepsCount / _totalSteps;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assistant_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'دليل البداية السريعة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            Text(
                              progress == 1
                                  ? 'مكتمل'
                                  : '$_completedStepsCount/$_totalSteps',
                              style: TextStyle(
                                color: progress == 1
                                    ? Colors.green
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                            color: progress == 1
                                ? Colors.green
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (!_isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _GuideNotice(ready: _autoImportEnabled),
                  const SizedBox(height: 14),
                  _GuideStep(
                    number: 1,
                    completed: _hasSmsPermission,
                    icon: Icons.shield_outlined,
                    title: 'منح صلاحية رسائل SMS',
                    subtitle:
                        'الصلاحية مطلوبة لقراءة رسائل المحافظ المالية فقط على جهازك.',
                    actionLabel: 'منح الصلاحية',
                    busy: _busy,
                    onAction: _enableAutomaticSync,
                  ),
                  const SizedBox(height: 10),
                  _GuideStep(
                    number: 2,
                    completed: _autoImportEnabled,
                    icon: Icons.sync_lock_rounded,
                    title: 'تفعيل التسجيل التلقائي',
                    subtitle:
                        'كل رسالة مالية جديدة تُسجل وتحدّث رصيد المحفظة المطابقة.',
                    actionLabel: 'تفعيل المزامنة',
                    busy: _busy,
                    onAction: _enableAutomaticSync,
                  ),
                  const SizedBox(height: 10),
                  _GuideStep(
                    number: 3,
                    completed: widget.walletCount > 0,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'إضافة محافظك',
                    subtitle: widget.walletCount > 0
                        ? 'تم العثور على ${widget.walletCount} محفظة جاهزة للربط.'
                        : 'أضف محفظة ليعرف التطبيق أين يسجل كل حركة.',
                    actionLabel: 'إضافة محفظة',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddWalletScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GuideStep(
                    number: 4,
                    completed: _initialScanCompleted,
                    icon: Icons.mark_email_read_outlined,
                    title: 'فحص الرسائل السابقة',
                    subtitle:
                        'راجع الرسائل المالية القديمة واستورد الحركات التي تريدها.',
                    actionLabel: 'فحص الرسائل',
                    onAction: () async {
                      await Navigator.pushNamed(context, AppRoutes.smsSync);
                      await _checkStatuses();
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => AppHintsModal.show(context),
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text('الجولة الإرشادية الكاملة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('dismissed_new_user_guide', true);
                          widget.onDismiss();
                        },
                        child: const Text('إخفاء'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuideNotice extends StatelessWidget {
  final bool ready;
  const _GuideNotice({required this.ready});

  @override
  Widget build(BuildContext context) {
    final color = ready ? Colors.green : Colors.amber.shade800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.tips_and_updates_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? 'ممتاز: استقبال الرسائل والتسجيل التلقائي جاهزان.'
                  : 'ابدأ بالخطوتين الأولى والثانية لتعمل مزامنة SMS فعلياً.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int number;
  final bool completed;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool busy;

  const _GuideStep({
    required this.number,
    required this.completed,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: completed
              ? Colors.green.withValues(alpha: 0.35)
              : AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: completed
                    ? Colors.green.withValues(alpha: 0.14)
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  completed ? Icons.check_rounded : icon,
                  color: completed ? Colors.green : AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              Positioned(
                right: -4,
                top: -5,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: completed
                      ? Colors.green
                      : AppTheme.primaryColor,
                  child: Text(
                    '$number',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (completed)
            const Icon(Icons.verified_rounded, color: Colors.green)
          else
            FilledButton(
              onPressed: busy ? null : onAction,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
              ),
              child: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(actionLabel, style: const TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }
}
