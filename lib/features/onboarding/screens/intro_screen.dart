import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';
import 'package:mizaan/features/auth/screens/biometric_gate_screen.dart';
import 'package:mizaan/features/auth/screens/login_screen.dart';
import 'package:mizaan/features/home/screens/home_screen.dart';

class IntroScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const IntroScreen({super.key, required this.prefs});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_IntroSlideData> _slides = const [
    _IntroSlideData(
      icon: Icons.account_balance_wallet_outlined,
      title: 'محافظك مشتتة؟',
      description:
          'كاش، محفظتي، جوالي، وغيرها... صعوبة في تتبع رصيدك ومصاريفك بين تطبيقات متعددة دون رؤية شاملة.',
    ),
    _IntroSlideData(
      icon: Icons.pie_chart_outline_rounded,
      title: 'اجمعها في مكان واحد',
      description:
          'ميزان يجمع إجمالي ثروتك وأرصدة جميع محافظك الإلكترونية في لوحة تحكم واحدة موحدة وسهلة.',
    ),
    _IntroSlideData(
      icon: Icons.mark_email_read_outlined,
      title: 'وراقب كل ريال تلقائياً',
      description:
          'استيراد ذكي للحركات المالية من رسائل الـ SMS تلقائياً مع تنبيهات عند انخفاض الرصيد وتقارير دقيقة.',
    ),
    _IntroSlideData(
      icon: Icons.security_rounded,
      title: 'أمانك وخصوصيتك أولويتنا 🔒',
      description:
          'نقرأ فقط إشعارات البنوك محلياً داخل هاتفك وبدون إنترنت. لا نصل لمحادثاتك الشخصية، وبياناتك المالية مشفرة وملكك وحدك.',
      badges: ['خصوصية محلية 100%', 'بدون رفع لسيرفرات', 'خفيف على البطارية'],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntro() async {
    await widget.prefs.setBool('introSeen', true);
    if (!mounted) return;

    Widget destination = const LoginScreen();
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is Authenticated) {
        destination = const HomeScreen();
      } else if (authState is BiometricRequired) {
        destination = const BiometricGateScreen();
      }
    } catch (_) {
      destination = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveConstraint(
          maxWidth: 550,
          alignment: Alignment.center,
          child: Column(
            children: [
              // Top Bar: Skip button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isLastPage
                      ? const SizedBox(height: 48)
                      : TextButton(
                          onPressed: _completeIntro,
                          child: const Text(
                            'تخطي',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 12.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.25,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                slide.icon,
                                size: 58,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.5,
                              ),
                            ),
                            if (slide.badges != null &&
                                slide.badges!.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: slide.badges!
                                    .map(
                                      (b) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 14,
                                              color: AppTheme.primaryColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              b,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Area: Indicators & Navigation Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Page Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: _currentIndex == index ? 28.0 : 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? AppTheme.primaryColor
                                : Colors.grey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Next / Get Started Button
                    ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _completeIntro();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isLastPage ? 'ابدأ الآن' : 'التالي',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

class _IntroSlideData {
  final IconData icon;
  final String title;
  final String description;
  final List<String>? badges;

  const _IntroSlideData({
    required this.icon,
    required this.title,
    required this.description,
    this.badges,
  });
}
