import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';
import 'package:mizaan/features/auth/screens/biometric_gate_screen.dart';
import 'package:mizaan/features/auth/screens/login_screen.dart';
import 'package:mizaan/features/home/screens/home_screen.dart';
import 'package:mizaan/features/onboarding/screens/intro_screen.dart';

class SplashScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const SplashScreen({super.key, required this.prefs});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Coin 1 animations
  late final Animation<double> _coin1Scale;
  late final Animation<Offset> _coin1Slide;

  // Coin 2 animations
  late final Animation<double> _coin2Scale;
  late final Animation<Offset> _coin2Slide;

  // Coin 3 animations
  late final Animation<double> _coin3Scale;
  late final Animation<Offset> _coin3Slide;

  // Coins merge fade out
  late final Animation<double> _coinsMergeOpacity;

  // Wallet pop animation (elastic)
  late final Animation<double> _walletScale;

  // Text fade and slide in
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Coins scale in (0.0 -> 0.35)
    _coin1Scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutBack),
      ),
    );
    _coin2Scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.36, curve: Curves.easeOutBack),
      ),
    );
    _coin3Scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.40, curve: Curves.easeOutBack),
      ),
    );

    // Coins slide toward center to merge (0.28 -> 0.52)
    _coin1Slide = Tween<Offset>(begin: const Offset(-75, -40), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.28, 0.52, curve: Curves.easeInOutCubic),
          ),
        );
    _coin2Slide = Tween<Offset>(begin: const Offset(75, -40), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.28, 0.52, curve: Curves.easeInOutCubic),
          ),
        );
    _coin3Slide = Tween<Offset>(begin: const Offset(0, 65), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.28, 0.52, curve: Curves.easeInOutCubic),
          ),
        );

    // Coins disappear as they merge (0.48 -> 0.56)
    _coinsMergeOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.56, curve: Curves.easeIn),
      ),
    );

    // Wallet pops with elastic curve (0.50 -> 0.82)
    _walletScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.82, curve: Curves.elasticOut),
      ),
    );

    // Text fades in and slides up (0.68 -> 0.95)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.95, curve: Curves.easeIn),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.68, 0.95, curve: Curves.easeOutCubic),
          ),
        );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateNext();
      }
    });

    _controller.forward();
  }

  void _navigateNext() {
    if (!mounted) return;

    final introSeen = widget.prefs.getBool('introSeen') ?? false;

    if (!introSeen) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => IntroScreen(prefs: widget.prefs),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }

    final authState = context.read<AuthCubit>().state;
    Widget destination;

    if (authState is Authenticated) {
      destination = const HomeScreen();
    } else if (authState is BiometricRequired) {
      destination = const BiometricGateScreen();
    } else {
      destination = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCoinWidget({required String label}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.accentColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : AppTheme.lightBackground,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coin merge into wallet stage
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Animated Coins merging in
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final opacity = _coinsMergeOpacity.value;
                        if (opacity <= 0.0) return const SizedBox.shrink();

                        return Opacity(
                          opacity: opacity,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Coin 1
                              Transform.translate(
                                offset: _coin1Slide.value,
                                child: Transform.scale(
                                  scale: _coin1Scale.value,
                                  child: _buildCoinWidget(label: '﷼'),
                                ),
                              ),
                              // Coin 2
                              Transform.translate(
                                offset: _coin2Slide.value,
                                child: Transform.scale(
                                  scale: _coin2Scale.value,
                                  child: _buildCoinWidget(label: '﷼'),
                                ),
                              ),
                              // Coin 3
                              Transform.translate(
                                offset: _coin3Slide.value,
                                child: Transform.scale(
                                  scale: _coin3Scale.value,
                                  child: _buildCoinWidget(label: '﷼'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Wallet icon pops with elastic curve
                    AnimatedBuilder(
                      animation: _walletScale,
                      builder: (context, child) {
                        final scale = _walletScale.value;
                        if (scale <= 0.01) return const SizedBox.shrink();

                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.6),
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // App Name & Slogan
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      const Text(
                        'ميزان',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'مجمع المحافظ وتتبع المصاريف',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
