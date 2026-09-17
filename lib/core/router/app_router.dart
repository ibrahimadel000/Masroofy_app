import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/features/auth/screens/login_screen.dart';
import 'package:mizaan/features/auth/screens/register_screen.dart';
import 'package:mizaan/features/favorites/screens/favorites_screen.dart';
import 'package:mizaan/features/home/screens/home_screen.dart';
import 'package:mizaan/features/onboarding/screens/intro_screen.dart';
import 'package:mizaan/features/splash/screens/splash_screen.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/settings/screens/settings_screen.dart';
import 'package:mizaan/features/sms/screens/sms_sync_screen.dart';
import 'package:mizaan/features/stats/screens/stats_screen.dart';
import 'package:mizaan/features/wallets/screens/add_wallet_screen.dart';
import 'package:mizaan/features/transactions/screens/transactions_history_screen.dart';
import 'package:mizaan/features/auth/screens/biometric_gate_screen.dart';
import 'package:mizaan/features/wallets/screens/wallet_details_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String intro = '/intro';
  static const String login = '/login';
  static const String register = '/register';
  static const String biometricGate = '/biometric-gate';
  static const String home = '/home';
  static const String addWallet = '/add-wallet';
  static const String addTransaction = '/add-transaction';
  static const String transactions = '/transactions';
  static const String favorites = '/favorites';
  static const String stats = '/stats';
  static const String settings = '/settings';
  static const String smsSync = '/sms-sync';

  static Route<dynamic>? onGenerateRoute(RouteSettings routeSettings, SharedPreferences prefs) {
    // Dynamic route: /wallet/:id
    if (routeSettings.name != null && routeSettings.name!.startsWith('/wallet/')) {
      final walletId = routeSettings.name!.replaceFirst('/wallet/', '');
      return MaterialPageRoute(
        builder: (_) => WalletDetailsScreen(walletId: walletId),
        settings: routeSettings,
      );
    }

    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => SplashScreen(prefs: prefs),
          settings: routeSettings,
        );
      case intro:
        return MaterialPageRoute(
          builder: (_) => IntroScreen(prefs: prefs),
          settings: routeSettings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: routeSettings,
        );
      case register:
        final fromLogin = routeSettings.arguments is bool ? routeSettings.arguments as bool : false;
        return MaterialPageRoute(
          builder: (_) => RegisterScreen(fromLogin: fromLogin),
          settings: routeSettings,
        );
      case biometricGate:
        return MaterialPageRoute(
          builder: (_) => const BiometricGateScreen(),
          settings: routeSettings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: routeSettings,
        );
      case addWallet:
        return MaterialPageRoute(
          builder: (_) => const AddWalletScreen(),
          settings: routeSettings,
        );
      case addTransaction:
        final initialWalletId = routeSettings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => AddTransactionScreen(initialWalletId: initialWalletId),
          settings: routeSettings,
        );
      case transactions:
        final initialWalletId = routeSettings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => TransactionsHistoryScreen(isEmbedded: false, initialWalletId: initialWalletId),
          settings: routeSettings,
        );
      case favorites:
        return MaterialPageRoute(
          builder: (_) => const FavoritesScreen(isEmbedded: false),
          settings: routeSettings,
        );
      case stats:
        return MaterialPageRoute(
          builder: (_) => const StatsScreen(isEmbedded: false),
          settings: routeSettings,
        );
      case smsSync:
        return MaterialPageRoute(
          builder: (_) => const SmsSyncScreen(),
          settings: routeSettings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(isEmbedded: false),
          settings: routeSettings,
        );
      default:
        return null;
    }
  }
}
