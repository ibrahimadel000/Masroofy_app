import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/responsive.dart';

enum PermissionEducationType {
  sms,
  battery,
}

class PermissionEducationSheet extends StatefulWidget {
  final PermissionEducationType type;

  const PermissionEducationSheet({
    super.key,
    required this.type,
  });

  /// Static helper to display the sheet easily from anywhere
  static Future<bool> show(
    BuildContext context, {
    required PermissionEducationType type,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PermissionEducationSheet(type: type),
    );
    return result ?? false;
  }

  @override
  State<PermissionEducationSheet> createState() => _PermissionEducationSheetState();
}

class _PermissionEducationSheetState extends State<PermissionEducationSheet> {
  bool _isLoading = false;

  bool get _isSms => widget.type == PermissionEducationType.sms;

  Future<void> _handleRequestPermission() async {
    if (!Platform.isAndroid) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isLoading = true);

    bool granted = false;
    try {
      if (_isSms) {
        final status = await Permission.sms.request();
        granted = status.isGranted;
      } else {
        await Permission.ignoreBatteryOptimizations.request();
        // Allow a brief delay for Android PowerManager to update state
        for (int i = 0; i < 4; i++) {
          await Future.delayed(Duration(milliseconds: i == 0 ? 250 : 350));
          if (!mounted) return;
          granted = await Permission.ignoreBatteryOptimizations.isGranted;
          if (granted) break;
        }
      }
    } catch (_) {
      granted = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, granted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2430) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28.0,
      ),
      child: ResponsiveConstraint(
        maxWidth: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Top grab handle
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 20),

            // Top Icon with glow
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isSms
                      ? [AppTheme.primaryColor, AppTheme.secondaryColor]
                      : [Colors.amber.shade700, Colors.orange.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isSms ? AppTheme.primaryColor : Colors.orange)
                        .withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                _isSms ? Icons.mark_email_read_rounded : Icons.battery_charging_full_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              _isSms ? 'تفعيل القراءة الذكية للرسائل' : 'السماح بالعمل في الخلفية',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              _isSms
                  ? 'يتعرف ميزان تلقائياً على إشعارات البنوك والمحافظ اليمنية لتدوين مصاريفك وإيداعاتك فوراً.'
                  : 'لضمان استلام رسائل البنوك وتحديث رصيد محافظك فوراً دون تأخير حتى عندما يكون التطبيق مغلقاً.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.45,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Reassurance badges / points
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : (_isSms ? Colors.blue.shade50 : Colors.amber.shade50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : (_isSms ? Colors.blue.shade100 : Colors.amber.shade200),
                ),
              ),
              child: Column(
                children: _isSms ? _buildSmsAssurances(isDark) : _buildBatteryAssurances(isDark),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Secondary / Later button
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      'لاحقاً',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Primary / Confirm button
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRequestPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSms ? AppTheme.primaryColor : Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isSms ? Icons.security_rounded : Icons.bolt_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isSms ? 'تفعيل الآن' : 'السماح بالخلفية',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  List<Widget> _buildSmsAssurances(bool isDark) {
    return [
      _buildAssuranceRow(
        icon: Icons.lock_outline_rounded,
        iconColor: Colors.blue.shade700,
        title: 'خصوصية وأمان 100%',
        description: 'المعالجة تتم بالكامل داخل هاتفك محلياً. لا نرفع أي رسالة لسيرفر خارجي أبداً.',
        isDark: isDark,
      ),
      const Divider(height: 16),
      _buildAssuranceRow(
        icon: Icons.account_balance_outlined,
        iconColor: Colors.teal.shade700,
        title: 'بنوك ومحافظ فقط',
        description: 'نتجاهل رسائلك ومحادثاتك الشخصية تلقائياً؛ نقرأ فقط إشعارات البنوك المعتمدة.',
        isDark: isDark,
      ),
      const Divider(height: 16),
      _buildAssuranceRow(
        icon: Icons.auto_mode_rounded,
        iconColor: AppTheme.primaryColor,
        title: 'راحة وتتبع فوري',
        description: 'تسجيل المصاريف والإيداعات تلقائياً مع كل عملية دون الحاجة للكتابة اليدوية.',
        isDark: isDark,
      ),
    ];
  }

  List<Widget> _buildBatteryAssurances(bool isDark) {
    return [
      _buildAssuranceRow(
        icon: Icons.eco_rounded,
        iconColor: Colors.green.shade700,
        title: 'استهلاك طاقة شبه معدوم (0.1%)',
        description: 'التطبيق يظل في خمول تام ولا ينشط إلا لأجزاء من الثانية عند وصول إشعار بنكي.',
        isDark: isDark,
      ),
      const Divider(height: 16),
      _buildAssuranceRow(
        icon: Icons.phonelink_setup_rounded,
        iconColor: Colors.orange.shade800,
        title: 'منع النظام من إيقاف المزامنة',
        description: 'أندرويد قد يوقف التطبيقات لتوفير الطاقة، هذا الإذن يبقي تحديث رصيدك سريعاً ودقيقاً.',
        isDark: isDark,
      ),
    ];
  }

  Widget _buildAssuranceRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.35,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
