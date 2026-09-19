import 'package:flutter/material.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/responsive.dart';

class AppHintsModal extends StatelessWidget {
  const AppHintsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppHintsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B202B) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Grab handle
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'دليل وتلميحات ميزان',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'كل ما تحتاج لمعرفته لتحقيق أقصى استفادة من التطبيق',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content List
              Expanded(
                child: ResponsiveConstraint(
                  maxWidth: 650,
                  alignment: Alignment.topCenter,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20.0),
                    children: [
                      _buildHintSection(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: AppTheme.primaryColor,
                        title: 'كيف يعمل ميزان مع الرسائل البنكية؟',
                        isDark: isDark,
                        children: const [
                          _HintItem(
                            number: '1',
                            title: 'الرصد الفوري للإشعارات',
                            content:
                                'عند وصول رسالة SMS من بنكك أو محفظتك (مثل الكريمي، جيب، ون كاش، فلوسك، محفظتي)، يحلل التطبيق نص الرسالة في أجزاء من الثانية.',
                          ),
                          _HintItem(
                            number: '2',
                            title: 'استخراج وتصنيف البيانات بدقة',
                            content:
                                'يتعرف المحرك الذكي على: نوع الحركة (خصم، إيداع، حوالة، شراء)، المبلغ، المحفظة المطابقة، الرصيد المتبقي بعد العملية.',
                          ),
                          _HintItem(
                            number: '3',
                            title: 'تحديث الرصيد والتنبيه الفوري',
                            content:
                                'يتم تحديث رصيد المحفظة وإجمالي ثروتك فوراً، وتصلك بطاقة إشعار جميلة بتفاصيل المعاملة دون أن تفتح التطبيق.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildHintSection(
                        icon: Icons.security_rounded,
                        iconColor: Colors.blue.shade700,
                        title: 'الخصوصية والأمان أولاً 🔒',
                        isDark: isDark,
                        children: const [
                          _HintItem(
                            number: '•',
                            title: 'معالجة محلية 100% بدون إنترنت',
                            content:
                                'جميع الرسائل يتم تحليلها محلياً على معالج هاتفك. لا يتم رفع أي رسالة أو رقم حساب لأي خادم سحابي إطلاقاً.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'حماية كاملة للرسائل الشخصية',
                            content:
                                'الفلتر الذكي يتجاهل أي رسالة لا تنتمي لأسماء مرسلي البنوك والمحافظ المالية المعتمدة، فرسائلك ومحادثاتك في أمان تام.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'قفل بالتطبيق وبصمة الإصبع',
                            content:
                                'يمكنك تفعيل القفل البيومتري (بصمة الإصبع / الوجه) من شاشة الإعدادات لمنع أي شخص من فتح ميزان.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildHintSection(
                        icon: Icons.battery_charging_full_rounded,
                        iconColor: Colors.orange.shade800,
                        title: 'العمل في الخلفية وإعدادات الهواتف ⚡',
                        isDark: isDark,
                        children: const [
                          _HintItem(
                            number: '•',
                            title: 'لماذا يطلب التطبيق إعفاء البطارية؟',
                            content:
                                'أنظمة أندرويد الحديثة تقوم بإيقاف التطبيقات عند قفل الشاشة لتوفير الطاقة. إعفاء التطبيق يضمن تسجيل حركاتك أولاً بأول دون تأخير.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'استهلاك الطاقة شبه منعدم',
                            content:
                                'ميزان مبرمج بتقنية الحدث (Event-Driven)، أي أنه ينام تماماً ولا يستيقظ إلا في اللحظة التي تصل فيها الرسالة.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'أجهزة شاومي، هواوي، وسامسونج',
                            content:
                                'إذا لاحظت عدم تسجيل الرسائل فوراً، تأكد من تفعيل "التشغيل التلقائي / Autostart" وضبط توفير البطارية على "بلا قيود" في إعدادات جهازك.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildHintSection(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: Colors.teal.shade700,
                        title: 'إدارة المحافظ والعملات 💱',
                        isDark: isDark,
                        children: const [
                          _HintItem(
                            number: '•',
                            title: 'تطابق المحافظ مع الرسائل',
                            content:
                                'عند إضافة محفظة جديدة، اختر اسمها بدقة (مثلاً: "الكريمي" أو "ون كاش")؛ ميزان يربط الرسائل تلقائياً بالمحفظة الأكثر تطابقاً.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'دعم العملات المتعددة',
                            content:
                                'يدعم ميزان العملات الرئيسية (الريال اليمني، الريال السعودي، الدولار الأمريكي) ويعرض إجمالي كل عملة بشكل منفصل في الشاشة الرئيسية.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'تسجيل المصاريف النقدية (الكاش)',
                            content:
                                'للمصاريف اليومية التي تدفعها نقداً في البقالة أو التاكسي، اضغط على زر "➕ حركة" وسجلها في ثوانٍ مع اختيار التصنيف المناسب.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildHintSection(
                        icon: Icons.sync_rounded,
                        iconColor: Colors.indigo.shade600,
                        title: 'مزامنة الرسائل القديمة 📥',
                        isDark: isDark,
                        children: const [
                          _HintItem(
                            number: '•',
                            title: 'استيراد الحركات السابقة بضغطة زر',
                            content:
                                'هل قمت بتثبيت التطبيق للتو؟ يمكنك الذهاب لشاشة "مزامنة الرسائل" لفحص صندوق الوارد واستيراد جميع رسائل البنوك السابقة تلقائياً.',
                          ),
                          _HintItem(
                            number: '•',
                            title: 'منع التكرار الذكي',
                            content:
                                'ميزان يمتلك بصمة فريدة لكل رسالة، مما يضمن عدم تكرار أي معاملة حتى إذا قمت بالمزامنة عدة مرات.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Bottom OK Button
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'فهمت، حسناً 👍',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHintSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _HintItem extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _HintItem({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
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
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
