import 'package:flutter/material.dart';
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
          }
        },
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
              onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, prefs),
              home: homeOverride ?? SplashScreen(prefs: prefs),
            );
          },
        ),
      ),
    );
  }
}
