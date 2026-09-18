import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/theme/theme_cubit.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/data/services/sms_service.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';
import 'package:mizaan/features/sms/cubit/sms_cubit.dart';
import 'package:mizaan/features/splash/screens/splash_screen.dart';
import 'package:mizaan/features/stats/cubit/stats_cubit.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class MizaanApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static bool _isBiometricGateOpen = false;

  final SharedPreferences prefs;
  final AuthRepository? authRepository;
  final BiometricService? biometricService;
  final WalletRepository? walletRepository;
  final TransactionRepository? transactionRepository;
  final Widget? homeOverride;

  const MizaanApp({
    super.key,
    required this.prefs,
    this.authRepository,
    this.biometricService,
    this.walletRepository,
    this.transactionRepository,
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
        BlocProvider<WalletsCubit>(
          create: (_) => WalletsCubit(
            repository: walletRepository ?? WalletRepository(),
          ),
        ),
        BlocProvider<TransactionsCubit>(
          create: (_) => TransactionsCubit(
            repository: transactionRepository ?? TransactionRepository(),
            walletRepository: walletRepository ?? WalletRepository(),
            notificationService: NotificationService(),
            prefs: prefs,
          ),
        ),
        BlocProvider<SmsCubit>(
          create: (_) => SmsCubit(
            smsService: const SmsService(),
            transactionRepository: transactionRepository ?? TransactionRepository(),
            notificationService: NotificationService(),
          ),
        ),
        BlocProvider<StatsCubit>(
          create: (_) => StatsCubit(
            transactionRepository: transactionRepository ?? TransactionRepository(),
            walletRepository: walletRepository ?? WalletRepository(),
          ),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, authState) async {
          if (authState is Authenticated) {
            final uid = authState.isGuest ? 'guest' : authState.user?.uid;
            await DatabaseService.switchUser(uid);
            if (context.mounted) {
              context.read<WalletsCubit>().loadWallets();
              context.read<TransactionsCubit>().loadTransactions();
              context.read<StatsCubit>().loadStats();

              if (!authState.isGuest && authState.user != null) {
                final wRepo = walletRepository ?? WalletRepository();
                final txRepo = transactionRepository ?? TransactionRepository();
                wRepo.syncFromFirestore().then((_) {
                  if (context.mounted) context.read<WalletsCubit>().loadWallets();
                });
                txRepo.syncFromFirestore().then((_) {
                  if (context.mounted) {
                    context.read<TransactionsCubit>().loadTransactions();
                    context.read<StatsCubit>().loadStats();
                  }
                });
              }
            }
          } else if (authState is Unauthenticated) {
            context.read<WalletsCubit>().reset();
            context.read<TransactionsCubit>().reset();
            context.read<StatsCubit>().reset();
            context.read<SmsCubit>().reset();
          } else if (authState is BiometricRequired) {
            if (!MizaanApp._isBiometricGateOpen && MizaanApp.navigatorKey.currentState != null) {
              MizaanApp._isBiometricGateOpen = true;
              MizaanApp.navigatorKey.currentState!
                  .pushNamed(AppRoutes.biometricGate)
                  .then((_) {
                MizaanApp._isBiometricGateOpen = false;
              });
            }
          }
        },
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              navigatorKey: MizaanApp.navigatorKey,
              title: 'ميزان',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              locale: const Locale('ar'),
              supportedLocales: const [
                Locale('ar'),
                Locale('en'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                final clampedMediaQuery = mediaQuery.copyWith(
                  textScaler: mediaQuery.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.30,
                  ),
                );
                return MediaQuery(
                  data: clampedMediaQuery,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _AppLifecycleGate(child: child ?? const SizedBox.shrink()),
                  ),
                );
              },
              onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, prefs),
              home: homeOverride ?? SplashScreen(prefs: prefs),
            );
          },
        ),
      ),
    );
  }
}

class _AppLifecycleGate extends StatefulWidget {
  final Widget child;
  const _AppLifecycleGate({required this.child});

  @override
  State<_AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends State<_AppLifecycleGate> with WidgetsBindingObserver {
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (BiometricService.isAuthenticating) {
      _pausedTime = null;
      return;
    }
    if (state == AppLifecycleState.paused) {
      _pausedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        _pausedTime = null;
        // Lock after 10 seconds of being in the background
        if (elapsed.inSeconds >= 10 && mounted) {
          final authCubit = context.read<AuthCubit>();
          authCubit.lockSession();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

