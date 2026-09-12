import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/theme/theme_cubit.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/splash/screens/splash_screen.dart';

class MizaanApp extends StatelessWidget {
  final SharedPreferences prefs;
  final AuthRepository? authRepository;
  final BiometricService? biometricService;
  final Widget? homeOverride;

  const MizaanApp({
    super.key,
    required this.prefs,
    this.authRepository,
    this.biometricService,
    this.homeOverride,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(prefs: prefs),
        ),
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(
            authRepository: authRepository ?? AuthRepository(),
            biometricService: biometricService ?? BiometricService(),
            prefs: prefs,
          )..checkAuthStatus(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'ميزان',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: homeOverride ?? SplashScreen(prefs: prefs),
          );
        },
      ),
    );
  }
}
