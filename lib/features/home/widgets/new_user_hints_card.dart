import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
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
  bool _isBatteryOptimized = false;

  @override
  void initState() {
    super.initState();
    _checkStatuses();
  }

  Future<void> _checkStatuses() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _hasSmsPermission = true;
          _isBatteryOptimized = true;
        });
      }
      return;
    }

    try {
      final sms = await const SmsService().hasPermission();
      final batt = await Permission.ignoreBatteryOptimizations.isGranted;

      if (mounted) {
        setState(() {
          _hasSmsPermission = sms;
          _isBatteryOptimized = batt;
        });
      }
    } catch (_) {}
  }

  int get _completedStepsCount {
    int count = 0;
    if (_hasSmsPermission) count++;
    if (_isBatteryOptimized) count++;
    if (widget.walletCount > 0) count++;
    return count;
  }

  int get _totalSteps => 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _completedStepsCount / _totalSteps;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.blue.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blue.shade900).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          InkWell(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'دليل البداية السريعة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: progress == 1.0
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                progress == 1.0 ? 'مكتمل 🎉' : '$_completedStepsCount من $_totalSteps',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: progress == 1.0 ? Colors.green.shade700 : AppTheme.primaryColor,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Mini progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress == 1.0 ? Colors.green : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                    tooltip: _isCollapsed ? 'توسيع' : 'طي',
                  ),
                ],
              ),
            ),
          ),

          if (!_isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Step 1: SMS Permission
                  _buildStepItem(
                    isCompleted: _hasSmsPermission,
                    icon: Icons.mark_email_read_rounded,
                    title: 'تفعيل القراءة الذكية للرسائل',
                    subtitle: 'يتعرف ميزان تلقائياً على إشعارات البنوك لتسجيل حركاتك ومصاريفك فوراً.',
                    actionLabel: 'تفعيل الآن 🔒',
                    onAction: () async {
                      final granted = await PermissionEducationSheet.show(
                        context,
                        type: PermissionEducationType.sms,
                      );
                      if (granted && mounted) {
                        await _checkStatuses();
                        widget.onPermissionUpdated?.call();
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Step 2: Battery Optimization
                  _buildStepItem(
                    isCompleted: _isBatteryOptimized,
                    icon: Icons.battery_charging_full_rounded,
                    title: 'السماح بالعمل في الخلفية',
                    subtitle: 'يضمن استلام الرسائل وتحديث رصيد محافظك فوراً دون تأخير (استهلاك 0%).',
                    actionLabel: 'تفعيل ⚡',
                    onAction: () async {
                      final granted = await PermissionEducationSheet.show(
                        context,
                        type: PermissionEducationType.battery,
                      );
                      if (granted && mounted) {
                        await _checkStatuses();
                        widget.onPermissionUpdated?.call();
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Step 3: Wallets Check
                  _buildStepItem(
                    isCompleted: widget.walletCount > 0,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'ضبط محافظك الإلكترونية',
                    subtitle: widget.walletCount > 0
                        ? 'لديك ${widget.walletCount} محفظة نشطة في ميزان.'
                        : 'أضف محافظك (الكريمي، ون كاش، جيب، كاش) لترتبط بالرسائل تلقائياً.',
                    actionLabel: widget.walletCount > 0 ? 'إضافة محفظة' : 'أضف محفظة الآن',
                    onAction: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddWalletScreen()),
                      );
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Step 4: SMS Sync (Import past messages)
                  _buildStepItem(
                    isCompleted: false, // Informational/repeatable action
                    icon: Icons.sync_rounded,
                    title: 'استيراد الرسائل السابقة من هاتفك',
                    subtitle: 'افحص صندوق الرسائل لاستيراد حركات البنوك السابقة دفعة واحدة.',
                    actionLabel: 'فحص الرسائل 📥',
                    onAction: () {
                      Navigator.pushNamed(context, AppRoutes.smsSync);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Subtle Tip for cash expenses
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.amber.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '💡 تلميح: الحركات البنكية تُسجل تلقائياً، ويمكنك تسجيل مصاريف الكاش في أي وقت عبر زر ➕ أسفل الشاشة.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => AppHintsModal.show(context),
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: const Text(
                          'تصفح دليل ميزان الكامل 💡',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('dismissed_new_user_guide', true);
                          widget.onDismiss();
                        },
                        child: Text(
                          'إخفاء الدليل',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                            fontFamily: 'Cairo',
                          ),
                        ),
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

  Widget _buildStepItem({
    required bool isCompleted,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_rounded : icon,
              color: isCompleted ? Colors.green.shade700 : AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? (isDark ? Colors.white70 : Colors.black87) : null,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.3,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'مُفعّل ✅',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontFamily: 'Cairo',
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                minimumSize: const Size(0, 34),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
        ],
      ),
    );
  }
}
