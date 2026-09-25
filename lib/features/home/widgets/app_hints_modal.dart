import 'package:flutter/material.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/responsive.dart';

class AppHintsModal extends StatefulWidget {
  const AppHintsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppHintsModal(),
    );
  }

  @override
  State<AppHintsModal> createState() => _AppHintsModalState();
}

class _AppHintsModalState extends State<AppHintsModal> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _steps = <_GuidePageData>[
    _GuidePageData(
      icon: Icons.waving_hand_rounded,
      color: AppTheme.primaryColor,
      eyebrow: 'مرحباً بك في ميزان',
      title: 'جولة قصيرة تضبط التطبيق بطريقة صحيحة',
      description:
          'خلال خمس خطوات ستعرف كيف تربط محافظك، تفعل رسائل SMS، وتراجع الحركات قبل حفظها.',
      notice: 'لن تظهر أي ميزة كمفعلة إلا بعد منح صلاحيتها فعلياً.',
      bullets: [
        'إعداد واضح خطوة بخطوة',
        'حالة حقيقية لكل صلاحية',
        'يمكنك إعادة هذه الجولة من الإعدادات',
      ],
    ),
    _GuidePageData(
      icon: Icons.account_balance_wallet_rounded,
      color: Colors.teal,
      eyebrow: 'الخطوة الأولى',
      title: 'أضف محافظك بأسمائها الصحيحة',
      description:
          'أنشئ محفظة لكل حساب مالي تستخدمه، مثل الكريمي أو جيب أو ون كاش، حتى يربط ميزان كل رسالة بالمحفظة الصحيحة.',
      notice: 'لا يخمّن التطبيق وجهة الحركة المالية إذا لم يجد محفظة مطابقة.',
      bullets: [
        'اختر نوع المحفظة الصحيح',
        'حدد العملة بدقة',
        'يمكنك إضافة أكثر من محفظة',
      ],
    ),
    _GuidePageData(
      icon: Icons.sms_rounded,
      color: Colors.indigo,
      eyebrow: 'الخطوة الثانية',
      title: 'فعّل استقبال رسائل SMS',
      description:
          'من الإعدادات فعّل «استقبال وتسجيل رسائل SMS تلقائياً»، ثم وافق على نافذة صلاحية الرسائل التي يعرضها أندرويد.',
      notice: 'يجب أن تظهر حالتا «الصلاحية ممنوحة» و«مزامنة الرسائل جاهزة».',
      bullets: [
        'الرسائل المالية تُحلل محلياً على الهاتف',
        'الرسائل من المرسلين غير المدعومين تُتجاهل',
        'يمكنك إيقاف التسجيل التلقائي في أي وقت',
      ],
    ),
    _GuidePageData(
      icon: Icons.manage_search_rounded,
      color: Colors.deepOrange,
      eyebrow: 'الخطوة الثالثة',
      title: 'افحص الرسائل السابقة وراجعها',
      description:
          'استخدم «فحص الرسائل الآن» لاستيراد الحركات السابقة. راجع المبلغ والمحفظة المحددة قبل الضغط على الاستيراد.',
      notice: 'منع التكرار يحميك عند إعادة الفحص أكثر من مرة.',
      bullets: [
        'حدد الحركات التي تريد استيرادها',
        'غيّر المحفظة المستهدفة عند الحاجة',
        'الرصيد الوارد في رسالة البنك يُعامل كمرجع موثوق',
      ],
    ),
    _GuidePageData(
      icon: Icons.verified_rounded,
      color: Colors.green,
      eyebrow: 'أصبحت جاهزاً',
      title: 'راقب الحركات والرصيد تلقائياً',
      description:
          'عند وصول رسالة مالية جديدة يسجل ميزان الحركة ويحدث رصيد المحفظة. اسحب الشاشة الرئيسية للأسفل لإجراء فحص إضافي.',
      notice:
          'إذا لم تُسجل رسالة، راجع حالة SMS في الإعدادات ثم استخدم «فحص الرسائل الآن».',
      bullets: [
        'التسجيل التلقائي للحركات الجديدة',
        'تحديث الرصيد من بيان البنك',
        'إشعارات خاصة بدون عرض نص الرسالة',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page == _steps.length - 1) {
      Navigator.maybePop(context);
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previous() async {
    if (_page == 0) return;
    await _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF171C27) : Colors.white;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'دليل ميزان التفاعلي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${_page + 1} من ${_steps.length}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_page + 1) / _steps.length,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white12
                        : Colors.grey.shade200,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ResponsiveConstraint(
                  maxWidth: 650,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _steps.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) =>
                        _GuidePage(data: _steps[index], isDark: isDark),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_page > 0)
                      OutlinedButton.icon(
                        onPressed: _previous,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('السابق'),
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('تخطي'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        _page == _steps.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_back_rounded,
                      ),
                      label: Text(
                        _page == _steps.length - 1 ? 'إنهاء الجولة' : 'التالي',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  final _GuidePageData data;
  final bool isDark;

  const _GuidePage({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color, size: 52),
          ),
          const SizedBox(height: 20),
          Text(
            data.eyebrow,
            style: TextStyle(
              color: data.color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: data.color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: data.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.notice,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...data.bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: data.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidePageData {
  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String description;
  final String notice;
  final List<String> bullets;

  const _GuidePageData({
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.notice,
    required this.bullets,
  });
}
