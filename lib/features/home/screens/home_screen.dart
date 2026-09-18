import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/features/favorites/screens/favorites_screen.dart';
import 'package:mizaan/features/sms/cubit/sms_cubit.dart';
import 'package:mizaan/features/settings/screens/settings_screen.dart';
import 'package:mizaan/features/stats/screens/stats_screen.dart';
import 'package:mizaan/features/wallets/screens/add_wallet_screen.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/features/wallets/screens/wallet_details_screen.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/sms_service.dart';
import 'package:mizaan/features/stats/cubit/stats_cubit.dart';
import 'package:mizaan/features/transactions/screens/transactions_history_screen.dart';
import 'package:mizaan/features/transactions/widgets/transaction_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentTabIndex = 0;
  bool _isOffline = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid) {
        _initSmsListenerAndPermissions();
        _triggerAutoImportIfEnabled();
        _checkBatteryOptimizationPromptOnce();
      } else {
        _runStartupDuplicateCleanupAndReconcile();
      }
      _checkNotificationPermissionOnce();
      _checkConnectivity();
    });

    // Dynamically poll connectivity every 4 seconds so the offline banner disappears promptly on reconnection
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _connectivityTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) _checkConnectivity();
      });
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
      if (Platform.isAndroid) {
        _triggerAutoImportIfEnabled();
      }
    }
  }

  Future<void> _initSmsListenerAndPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final notif = NotificationService();
      await notif.init();

      final smsService = const SmsService();
      final txRepo = TransactionRepository();
      final walletRepo = WalletRepository();

      await smsService.startIncomingSmsListener(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
        notificationService: notif,
        onTransactionReceived: (TransactionModel tx) {
          if (mounted) {
            context.read<TransactionsCubit>().loadTransactions();
            context.read<WalletsCubit>().loadWallets();
            context.read<StatsCubit>().loadStats();
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _checkConnectivity() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() => _isOffline = result.isEmpty || result[0].rawAddress.isEmpty);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isOffline = true);
      }
    }
  }

  Future<void> _checkNotificationPermissionOnce() async {
    final notif = NotificationService();
    await notif.init();
    final prefs = await SharedPreferences.getInstance();
    final hasPerm = await notif.hasPermission();
    if (!hasPerm) {
      final requestedBefore = prefs.getBool('notificationPermissionRequested') ?? false;
      if (!requestedBefore) {
        await prefs.setBool('notificationPermissionRequested', true);
        final granted = await notif.requestPermission();
        if (granted) {
          final uid = DatabaseService.currentUserId ?? 'guest';
          final reminder = prefs.getBool('${uid}_dailyReminderEnabled') ??
              prefs.getBool('dailyReminderEnabled') ??
              true;
          if (reminder) {
            await notif.scheduleDailyReminder();
          }
        }
      }
    } else {
      // Permission already granted / enabled (e.g. Android < 13 or user previously allowed)
      final uid = DatabaseService.currentUserId ?? 'guest';
      final reminder = prefs.getBool('${uid}_dailyReminderEnabled') ??
          prefs.getBool('dailyReminderEnabled') ??
          true;
      if (reminder) {
        await notif.scheduleDailyReminder();
      }
    }
  }

  Future<void> _checkBatteryOptimizationPromptOnce() async {
    if (!Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final requested = prefs.getBool('battery_opt_prompt_shown') ?? false;
      if (!requested) {
        await prefs.setBool('battery_opt_prompt_shown', true);
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }
    } catch (_) {}
  }

  Future<void> _triggerAutoImportIfEnabled() async {
    // 1. Flush any pending background SMS queue first
    final flushed = await SmsService.flushPendingBackgroundSms(
      transactionRepository: TransactionRepository(),
      walletRepository: WalletRepository(),
      notificationService: NotificationService(),
    );

    // 2. Clean existing duplicates
    final cleaned = await TransactionRepository().cleanDuplicateTransactions();
    if ((flushed > 0 || cleaned > 0) && mounted) {
      context.read<TransactionsCubit>().loadTransactions();
      context.read<WalletsCubit>().loadWallets();
      context.read<StatsCubit>().loadStats();
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = DatabaseService.currentUserId ?? 'guest';
    final autoImportEnabled = prefs.getBool('${uid}_smsAutoImportEnabled') ??
        prefs.getBool('smsAutoImportEnabled') ??
        true;

    int importedCount = 0;
    if (autoImportEnabled && mounted) {
      final walletsState = context.read<WalletsCubit>().state;
      List<Wallet> wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];
      if (wallets.isEmpty) {
        wallets = WalletRepository().getWallets();
      }
      if (wallets.isNotEmpty) {
        importedCount = await context.read<SmsCubit>().autoImportSilently(wallets: wallets);
        if (importedCount > 0 && mounted) {
          context.read<TransactionsCubit>().loadTransactions();
          context.read<WalletsCubit>().loadWallets();
          context.read<StatsCubit>().loadStats();
        }
      }
    }

    // 3. Reconcile wallets with the latest bank SMS statement balance
    final reconciled = await const SmsService().reconcileWalletsWithLatestSms(
      transactionRepository: TransactionRepository(),
      walletRepository: WalletRepository(),
    );
    if (reconciled > 0 && mounted) {
      context.read<WalletsCubit>().loadWallets();
      context.read<StatsCubit>().loadStats();
    }

    final totalNew = flushed + importedCount;
    if (totalNew > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('تم استيراد $totalNew حركات وتحديث الرصيد الإجمالي تلقائياً 📩'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _runStartupDuplicateCleanupAndReconcile() async {
    final cleaned = await TransactionRepository().cleanDuplicateTransactions();
    final reconciled = await const SmsService().reconcileWalletsWithLatestSms(
      transactionRepository: TransactionRepository(),
      walletRepository: WalletRepository(),
    );
    if ((cleaned > 0 || reconciled > 0) && mounted) {
      context.read<WalletsCubit>().loadWallets();
      context.read<TransactionsCubit>().loadTransactions();
      context.read<StatsCubit>().loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text(
              'ميزان',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          // Android-only SMS Quick Sync button in AppBar
          if (Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Text('📩', style: TextStyle(fontSize: 14)),
                label: const Text(
                  'مزامنة الرسائل',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.smsSync);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: (_currentTabIndex == 0 || _currentTabIndex == 1)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('➕ حركة'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'الحركات',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'التقارير',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOfflineBanner(),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final authState = context.watch<AuthCubit>().state;
    final isGuest = (authState is Authenticated && authState.isGuest) ||
        (DatabaseService.currentUserId == 'guest');
    if (isGuest || !_isOffline) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        color: Colors.amber.shade800,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'وضع أوفلاين — سيتم المزامنة لاحقاً',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _HomeMainView(
          onNavigateToTransactions: () => setState(() => _currentTabIndex = 1),
        );
      case 1:
        return const TransactionsHistoryScreen(isEmbedded: true);
      case 2:
        return const StatsScreen(isEmbedded: true);
      case 3:
        return const FavoritesScreen(isEmbedded: true);
      case 4:
        return const SettingsScreen(isEmbedded: true);
      default:
        return _HomeMainView(
          onNavigateToTransactions: () => setState(() => _currentTabIndex = 1),
        );
    }
  }
}

class _HomeMainView extends StatelessWidget {
  final VoidCallback onNavigateToTransactions;

  const _HomeMainView({required this.onNavigateToTransactions});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletsCubit, WalletsState>(
      builder: (context, walletsState) {
        final wallets = walletsState is WalletsLoaded ? walletsState.wallets : <Wallet>[];

        return BlocBuilder<TransactionsCubit, TransactionsState>(
          builder: (context, txState) {
            final transactions = txState is TransactionsLoaded ? txState.transactions : <TransactionModel>[];

            final totalsByCurrency = BalanceCalculator.calculateTotalsByCurrency(
              wallets: wallets,
              allTransactions: transactions,
            );
            final todaySpending = BalanceCalculator.calculateTodaySpending(transactions);

            return RefreshIndicator(
              onRefresh: () async {
                final flushed = await SmsService.flushPendingBackgroundSms(
                  transactionRepository: TransactionRepository(),
                  walletRepository: WalletRepository(),
                  notificationService: NotificationService(),
                );
                await TransactionRepository().cleanDuplicateTransactions();
                int imported = 0;
                if (Platform.isAndroid && context.mounted) {
                  final wallets = context.read<WalletsCubit>().state is WalletsLoaded
                      ? (context.read<WalletsCubit>().state as WalletsLoaded).wallets
                      : <Wallet>[];
                  if (wallets.isNotEmpty) {
                    imported = await context.read<SmsCubit>().autoImportSilently(wallets: wallets);
                  }
                }
                await const SmsService().reconcileWalletsWithLatestSms(
                  transactionRepository: TransactionRepository(),
                  walletRepository: WalletRepository(),
                );
                if (context.mounted) {
                  context.read<WalletsCubit>().loadWallets();
                  context.read<TransactionsCubit>().loadTransactions();
                  context.read<StatsCubit>().loadStats();
                  final totalUpdated = flushed + imported;
                  if (totalUpdated > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: Text('تم استيراد $totalUpdated حركات وتحديث الرصيد الإجمالي ✅'),
                      ),
                    );
                  }
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: ResponsiveConstraint(
                  maxWidth: 1050,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Total Balance Card
                      _buildTotalBalanceCard(totalsByCurrency, todaySpending),

                    const SizedBox(height: 24),

                    // 2. Horizontal Wallets List Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'محافظي',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${wallets.length}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddWalletScreen()),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('إضافة محفظة'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Horizontal Wallets Carousel
                    _buildWalletsHorizontalList(context, wallets, transactions),

                    const SizedBox(height: 28),

                    // 3. Recent Transactions Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'آخر الحركات المالية',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (transactions.isNotEmpty)
                            TextButton.icon(
                              onPressed: onNavigateToTransactions,
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: Text(
                                'عرض الكل (${transactions.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Recent Transactions List
                    _buildRecentTransactionsList(context, transactions, wallets),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildTotalBalanceCard(Map<String, double> totalsByCurrency, double todaySpending) {
    final entries = totalsByCurrency.entries.toList();
    final hasMultipleCurrencies = entries.length > 1;

    // Primary currency (YER if exists, else first)
    final primaryEntry = entries.firstWhere(
      (e) => e.key == 'YER',
      orElse: () => entries.isNotEmpty ? entries.first : const MapEntry('YER', 0.0),
    );

    // Other currencies
    final otherEntries = entries.where((e) => e.key != primaryEntry.key).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي الرصيد',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              AppConstants.formatCurrency(primaryEntry.value, primaryEntry.key),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (hasMultipleCurrencies) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: otherEntries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+ ${AppConstants.formatCurrency(e.value, e.key)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'مصروف اليوم: ${AppConstants.formatCurrency(todaySpending)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletsHorizontalList(
    BuildContext context,
    List<Wallet> wallets,
    List<TransactionModel> transactions,
  ) {
    if (wallets.isEmpty) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'لم تقم بإضافة أي محفظة بعد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddWalletScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('أضف محفظتك الأولى الآن'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 155,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: wallets.length + 1,
        itemBuilder: (context, index) {
          if (index == wallets.length) {
            // Add wallet card at end
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddWalletScreen()),
                );
              },
              child: Container(
                width: context.isTablet ? 150 : 130,
                margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'إضافة محفظة',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final wallet = wallets[index];
          final walletColor = Color(wallet.colorValue);
          final walletTx = transactions.where((tx) => tx.walletId == wallet.id).toList();
          final balance = BalanceCalculator.calculateWalletBalance(
            openingBalance: wallet.openingBalance,
            transactions: walletTx,
          );

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletDetailsScreen(walletId: wallet.id),
                ),
              );
            },
            child: Container(
              width: context.isTablet ? 215 : 175,
              margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: walletColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: walletColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        AppConstants.getWalletIcon(wallet.iconCodePoint),
                        color: Colors.white,
                        size: 24,
                      ),
                      GestureDetector(
                        onTap: () => context.read<WalletsCubit>().toggleFavorite(wallet.id),
                        child: Icon(
                          wallet.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: wallet.isFavorite ? Colors.amber : Colors.white70,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConstants.formatCurrency(balance, wallet.currencyCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTransactionsList(
    BuildContext context,
    List<TransactionModel> transactions,
    List<Wallet> wallets,
  ) {
    if (transactions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(22.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 44,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد حركات مسجلة بعد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'سجّل حركاتك النقدية يدوياً أو استورد رسائل المحافظ البنكية بضغطة زر.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('تسجيل حركة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.smsSync);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.mark_email_read_rounded, size: 18),
                      label: const Text('مزامنة SMS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    final recent = transactions.take(15).toList();

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: recent.length,
          itemBuilder: (context, index) {
            final tx = recent[index];
            final wallet = wallets.cast<Wallet?>().firstWhere(
                  (w) => w?.id == tx.walletId,
                  orElse: () => null,
                );

            final isIncome = tx.type == 'income';
            final isAdjustment = tx.type == 'adjustment';

            final Color amountColor = isIncome
                ? AppTheme.primaryColor
                : isAdjustment
                    ? Colors.blue.shade700
                    : Colors.red.shade700;
            final String prefix = isIncome
                ? '+'
                : isAdjustment
                    ? (tx.amount >= 0 ? '+' : '')
                    : '-';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                onTap: () => TransactionDetailSheet.show(context, tx),
                leading: CircleAvatar(
                  backgroundColor: amountColor.withValues(alpha: 0.12),
                  child: Icon(
                    AppConstants.getCategoryIcon(tx.category),
                    color: amountColor,
                    size: 22,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      tx.category,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (tx.source == 'sms') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('📩', style: TextStyle(fontSize: 10)),
                            SizedBox(width: 2),
                            Text(
                              'SMS',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${wallet?.name ?? "محفظة"} • ${AppConstants.formatDate(tx.date)}  ${AppConstants.formatTime(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? " • ${tx.note}" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '$prefix${AppConstants.formatCurrency(tx.amount.abs())}',
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: Text(
              transactions.length > 15
                  ? 'عرض كل الحركات (${transactions.length} حركة) ←'
                  : 'فتح والبحث في سجل الحركات ←',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: onNavigateToTransactions,
          ),
        ),
      ],
    );
  }
}


