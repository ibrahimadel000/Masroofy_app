import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/router/app_router.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/core/utils/responsive.dart';
import 'package:mizaan/core/utils/stats_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/features/stats/cubit/stats_cubit.dart';
import 'package:mizaan/features/stats/cubit/stats_state.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class StatsScreen extends StatefulWidget {
  final bool isEmbedded;

  const StatsScreen({super.key, this.isEmbedded = false});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final NumberFormat _fmt = NumberFormat('#,##0.##', 'ar');
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStats();
    });
  }

  void _refreshStats({DateTime? targetMonth}) {
    final txState = context.read<TransactionsCubit>().state;
    final wState = context.read<WalletsCubit>().state;
    final transactions = txState is TransactionsLoaded
        ? txState.transactions
        : <TransactionModel>[];
    final wallets = wState is WalletsLoaded ? wState.wallets : <Wallet>[];
    context.read<StatsCubit>().updateData(
      transactions: transactions,
      wallets: wallets,
      referenceDate: targetMonth,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'أكل':
      case 'طعام ومشروبات':
        return Colors.orange.shade700;
      case 'مواصلات':
        return Colors.blue.shade600;
      case 'بقالة':
      case 'تسوق':
        return Colors.green.shade600;
      case 'فواتير':
      case 'فواتير ومرافق':
        return Colors.red.shade500;
      case 'تحويل':
        return Colors.purple.shade600;
      case 'راتب':
        return Colors.teal.shade600;
      case 'صحة':
        return Colors.pink.shade600;
      case 'تعليم':
        return Colors.indigo.shade600;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  IconData _getCategoryIcon(String category) {
    return AppConstants.getCategoryIcon(category);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionsCubit, TransactionsState>(
          listener: (context, _) => _refreshStats(),
        ),
        BlocListener<WalletsCubit, WalletsState>(
          listener: (context, _) => _refreshStats(),
        ),
      ],
      child: widget.isEmbedded
          ? _buildBody()
          : Scaffold(
              appBar: AppBar(
                title: const Text('التقارير والإحصائيات'),
                centerTitle: true,
              ),
              body: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<StatsCubit, StatsState>(
      builder: (context, state) {
        if (state is StatsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (state is StatsError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.message,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshStats(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is! StatsLoaded) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final result = state.result;

        // 1. If entire app has no transactions at all
        if (!result.hasEnoughData) {
          return _buildAppEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async =>
              _refreshStats(targetMonth: state.selectedMonth),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: ResponsiveConstraint(
              maxWidth: 1100,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Month Navigation Header
                  _buildMonthHeader(state.selectedMonth),
                  const SizedBox(height: 14),

                  // 2. Wallet Filter Chips Bar
                  _buildWalletFilterBar(state),
                  const SizedBox(height: 16),

                  // If this specific month has no transactions, show monthly empty state
                  if (result.monthlyTransactionCount == 0) ...[
                    _buildMonthEmptyState(state.selectedMonth),
                  ] else ...[
                    // 3. Financial Overview Cards (Income, Expense, Net, Daily)
                    _buildFinancialOverviewGrid(result),
                    const SizedBox(height: 16),

                    // 4. Spending vs Income Progress Bar
                    if (result.totalMonthlyIncome > 0 ||
                        result.totalMonthlyExpense > 0) ...[
                      _buildIncomeExpenseRatioCard(result),
                      const SizedBox(height: 16),
                    ],

                    // 5. Rule-based Smart Insights
                    _buildInsightCards(result),
                    const SizedBox(height: 16),

                    // 6. Category Breakdown & Pie Section
                    _buildCategoryBreakdownSection(state, result),
                    const SizedBox(height: 16),

                    // 7. Daily Spending Bar Chart (Week / Month toggle)
                    _buildBarChartSection(state, result),
                    const SizedBox(height: 16),

                    // 8. Wallets Spending Breakdown (only when All Wallets is selected)
                    if (state.selectedWalletId == null) ...[
                      _buildWalletsBreakdown(context, result),
                      const SizedBox(height: 16),
                    ],
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletFilterBar(StatsLoaded state) {
    final walletsState = context.watch<WalletsCubit>().state;
    final wallets = walletsState is WalletsLoaded
        ? walletsState.wallets
        : <Wallet>[];

    if (wallets.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // "كل المحافظ" Chip
          ChoiceChip(
            label: const Text(
              'كل المحافظ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            avatar: const Icon(Icons.all_inclusive_rounded, size: 16),
            selected: state.selectedWalletId == null,
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: state.selectedWalletId == null
                  ? AppTheme.primaryColor
                  : null,
              fontWeight: FontWeight.bold,
            ),
            side: BorderSide(
              color: state.selectedWalletId == null
                  ? AppTheme.primaryColor
                  : Colors.grey.shade300,
            ),
            onSelected: (selected) {
              if (selected) {
                context.read<StatsCubit>().filterByWallet(null);
              }
            },
          ),
          const SizedBox(width: 8),

          // Chips for each wallet
          ...wallets.map((wallet) {
            final isSelected = state.selectedWalletId == wallet.id;
            final color = Color(wallet.colorValue);

            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: ChoiceChip(
                label: Text(
                  wallet.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                avatar: Icon(
                  AppConstants.getWalletIcon(wallet.iconCodePoint),
                  size: 15,
                  color: isSelected ? Colors.white : color,
                ),
                selected: isSelected,
                selectedColor: color,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                ),
                onSelected: (selected) {
                  context.read<StatsCubit>().filterByWallet(
                    selected ? wallet.id : null,
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthEmptyState(DateTime monthDate) {
    final monthName = AppConstants.formatMonthYear(monthDate);
    final now = DateTime.now();
    final isCurrentMonth =
        monthDate.year == now.year && monthDate.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
              color: Colors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 44,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد حركات مسجلة لشهر $monthName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم تسجيل أي مصاريف أو إيداعات في هذا الشهر حتى الآن.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddTransactionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    '➕ إضافة حركة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!isCurrentMonth) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      context.read<StatsCubit>().changeMonth(DateTime.now());
                    },
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text(
                      'العودة للشهر الحالي',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي الدخل',
                  value: '0 ر.ي',
                  subtitle: 'هذا الشهر',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي المصروفات',
                  value: '0 ر.ي',
                  subtitle: 'هذا الشهر',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: Colors.red.shade700,
                  bgColor: Colors.red.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(24),
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
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 52,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لوحة التقارير والتحليلات المالية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'لا توجد حركات مالية مسجلة بعد. عند إضافة مصاريفك أو استيراد رسائل البنوك والمحافظ، ستظهر هنا تلقائياً رسوم بيانية تفاعلية، وتحليلات أسبوعية وشهرية، واقتراحات ذكية لتوفير أموالك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddTransactionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      '➕ تسجيل حركة مالية الآن',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.smsSync);
                      },
                      icon: const Icon(Icons.mark_email_read_rounded),
                      label: const Text(
                        '📩 فحص واستيراد رسائل المحافظ SMS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    final monthName = AppConstants.formatMonthYear(date);
    final now = DateTime.now();
    final isCurrentMonth = date.year == now.year && date.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'الشهر السابق',
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: () {
              final prev = DateTime(date.year, date.month - 1, 1);
              context.read<StatsCubit>().changeMonth(prev);
            },
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrentMonth)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'الحالي',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      context.read<StatsCubit>().changeMonth(DateTime.now());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.replay_rounded,
                            size: 12,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'العودة لليوم',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'الشهر التالي',
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: isCurrentMonth
                ? null
                : () {
                    final next = DateTime(date.year, date.month + 1, 1);
                    context.read<StatsCubit>().changeMonth(next);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverviewGrid(StatsResult result) {
    final net = result.netSavings;
    final isNetPositive = net >= 0;
    final isWide = MediaQuery.sizeOf(context).width >= 768;

    final cardIncome = _buildMetricCard(
      title: 'إجمالي الدخل',
      value: '${_fmt.format(result.totalMonthlyIncome)} ر.ي',
      subtitle: 'إيداعات ورواتب',
      icon: Icons.arrow_downward_rounded,
      iconColor: Colors.green.shade700,
      bgColor: Colors.green.shade50,
    );

    final cardExpense = _buildMetricCard(
      title: 'إجمالي المصروفات',
      value: '${_fmt.format(result.totalMonthlyExpense)} ر.ي',
      subtitle: 'مصاريف وسداد',
      icon: Icons.arrow_upward_rounded,
      iconColor: Colors.red.shade700,
      bgColor: Colors.red.shade50,
    );

    final cardNet = _buildMetricCard(
      title: 'صافي الوفر',
      value: '${_fmt.format(net.abs())} ر.ي',
      subtitle: isNetPositive ? 'وفر إيجابي 🎉' : 'عجز مصروفات ⚠️',
      icon: isNetPositive ? Icons.savings_rounded : Icons.warning_amber_rounded,
      iconColor: isNetPositive ? AppTheme.primaryColor : Colors.orange.shade800,
      bgColor: isNetPositive ? Colors.teal.shade50 : Colors.orange.shade50,
    );

    final cardDaily = _buildMetricCard(
      title: 'المعدل اليومي',
      value: '${_fmt.format(result.dailyAverage)} ر.ي',
      subtitle: result.isCurrentMonth
          ? 'صرف يومي (${result.daysElapsed} يوم)'
          : 'معدل الشهر (${result.totalDaysInMonth} يوم)',
      icon: Icons.speed_rounded,
      iconColor: Colors.blue.shade600,
      bgColor: Colors.blue.shade50,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: cardIncome),
          const SizedBox(width: 12),
          Expanded(child: cardExpense),
          const SizedBox(width: 12),
          Expanded(child: cardNet),
          const SizedBox(width: 12),
          Expanded(child: cardDaily),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cardIncome),
            const SizedBox(width: 12),
            Expanded(child: cardExpense),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cardNet),
            const SizedBox(width: 12),
            Expanded(child: cardDaily),
          ],
        ),
      ],
    );
  }

  Widget _buildIncomeExpenseRatioCard(StatsResult result) {
    final income = result.totalMonthlyIncome;
    final expense = result.totalMonthlyExpense;

    double ratio = 0.0;
    if (income > 0) {
      ratio = (expense / income).clamp(0.0, 1.0);
    } else if (expense > 0) {
      ratio = 1.0;
    }

    final percent = (ratio * 100).toInt();

    final Color statusColor = ratio <= 0.65
        ? AppTheme.primaryColor
        : ratio <= 0.90
        ? Colors.orange.shade700
        : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'نسبة الصرف من إجمالي الدخل',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            income > 0
                ? (ratio <= 0.65
                      ? 'وضعك المالي ممتاز! صرفت $percent% وتوفر الباقي.'
                      : ratio <= 0.90
                      ? 'انتبه: صرفت $percent% من دخلك، راقب نفقاتك.'
                      : 'تحذير: المصروفات قاربت أو تجاوزت الدخل الشهري!')
                : 'لم تسجل دخلاً لهذا الشهر حتى الآن.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCards(StatsResult result) {
    return Column(
      children: [
        // Card 1: Month-over-Month Comparison (مقارنة بالشهر السابق)
        if (result.monthlyChangePercent != null &&
            (result.totalPrevMonthExpense > 0 ||
                result.totalMonthlyExpense > 0)) ...[
          _buildMonthlyComparisonCard(result),
          const SizedBox(height: 12),
        ],

        // Card 2: Weekly Spending Comparison (صرفك هذا الأسبوع مقارنة بالأسبوع الماضي - للشهر الحالي فقط)
        if (result.isCurrentMonth &&
            result.weeklyChangePercent != null &&
            (result.thisWeekExpense > 0 || result.lastWeekExpense > 0)) ...[
          _buildWeeklyComparisonCard(result),
          const SizedBox(height: 12),
        ],

        // Card 3: Top Spending Wallet (الخطوة 7 من الخطة الأصلية)
        if (result.topWalletName != null && result.topWalletAmount > 0) ...[
          _buildTopWalletCard(result),
          const SizedBox(height: 12),
        ],

        // Card 4: 10% Smart Saving Suggestion
        if (result.topCategory != null && result.savingsPotential > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade900],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 فكرة توفير ذكية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'لو خفّضت مصاريف "${result.topCategory}" بنسبة 10%، ستوفر ${_fmt.format(result.savingsPotential)} ر.ي شهرياً!',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMonthlyComparisonCard(StatsResult result) {
    final pct = result.monthlyChangePercent!;
    final bool isIncrease = pct > 0;
    final bool isIdentical = pct == 0;

    final Color badgeColor = isIdentical
        ? Colors.grey.shade700
        : (isIncrease ? Colors.red.shade700 : Colors.green.shade700);

    final Color bgColor = isIdentical
        ? Colors.grey.shade50
        : (isIncrease ? Colors.red.shade50 : Colors.green.shade50);

    final IconData icon = isIdentical
        ? Icons.remove_rounded
        : (isIncrease
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded);

    final String titleText = isIdentical
        ? 'مصروفاتك مطابقة تماماً للشهر السابق'
        : (isIncrease
              ? 'المصروفات ارتفعت ${pct.abs().toStringAsFixed(0)}% عن الشهر السابق ⚠️'
              : 'المصروفات انخفضت ${pct.abs().toStringAsFixed(0)}% مقارنة بالشهر السابق 🎉');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'هذا الشهر: ${_fmt.format(result.totalMonthlyExpense)} ر.ي | الشهر السابق: ${_fmt.format(result.totalPrevMonthExpense)} ر.ي',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopWalletCard(StatsResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المحفظة الأكثر صرفاً هذا الشهر',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.topWalletName ?? 'محفظة',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'إجمالي ما صُرف منها: ${_fmt.format(result.topWalletAmount)} ر.ي',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyComparisonCard(StatsResult result) {
    final pct = result.weeklyChangePercent!;
    final bool isIncrease = pct > 0;
    final bool isIdentical = pct == 0;

    final Color badgeColor = isIdentical
        ? Colors.grey.shade700
        : (isIncrease ? Colors.red.shade700 : Colors.green.shade700);

    final Color bgColor = isIdentical
        ? Colors.grey.shade50
        : (isIncrease ? Colors.red.shade50 : Colors.green.shade50);

    final IconData icon = isIdentical
        ? Icons.remove_rounded
        : (isIncrease
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded);

    final String titleText = isIdentical
        ? 'صرفك هذا الأسبوع مطابق للأسبوع الماضي'
        : (isIncrease
              ? 'صرفك زاد ${pct.abs().toStringAsFixed(0)}% مقارنة بالأسبوع الماضي ⚠️'
              : 'صرفك نقص ${pct.abs().toStringAsFixed(0)}% مقارنة بالأسبوع الماضي 🎉');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'هذا الأسبوع: ${_fmt.format(result.thisWeekExpense)} ر.ي | الأسبوع الماضي: ${_fmt.format(result.lastWeekExpense)} ر.ي',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownSection(StatsLoaded state, StatsResult result) {
    final isExpense = state.activeType == 'expense';
    final targetMap = isExpense
        ? result.categorySpending
        : result.categoryIncome;
    final total = isExpense
        ? result.totalMonthlyExpense
        : result.totalMonthlyIncome;
    final counts = isExpense
        ? result.categoryExpenseCount
        : result.categoryIncomeCount;

    final entries = targetMap.entries.where((e) => e.value > 0).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    final hasIncome = result.categoryIncome.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Expenses / Income Toggle
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                isExpense ? 'توزيع المصروفات بالتصنيف' : 'توزيع الدخل بالتصنيف',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasIncome)
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'expense',
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text('المصاريف', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text('الدخل', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                  selected: {state.activeType},
                  onSelectionChanged: (set) {
                    context.read<StatsCubit>().switchActiveType(set.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                Text(
                  'إجمالي: ${_fmt.format(total)} ر.ي',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (entries.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isExpense
                          ? 'لا توجد مصروفات مسجلة في هذا الشهر.'
                          : 'لا يوجد دخل مسجل في هذا الشهر.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Builder(
              builder: (context) {
                final isWide = MediaQuery.sizeOf(context).width >= 768;

                final pieChartWidget = SizedBox(
                  height: 210,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 46,
                      sections: List.generate(entries.length, (i) {
                        final entry = entries[i];
                        final isTouched = i == _touchedPieIndex;
                        final radius = isTouched ? 48.0 : 40.0;
                        final pct = total > 0
                            ? (entry.value / total) * 100
                            : 0.0;
                        final color = _getCategoryColor(entry.key);

                        return PieChartSectionData(
                          value: entry.value,
                          title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                          color: color,
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 14 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                );

                final categoryItems = entries.map((entry) {
                  final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
                  final color = _getCategoryColor(entry.key);
                  final count = counts[entry.key] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(
                                _getCategoryIcon(entry.key),
                                size: 16,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$count حركات • ${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_fmt.format(entry.value)} ر.ي',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isExpense
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 280,
                        child: Column(
                          children: [
                            pieChartWidget,
                            const SizedBox(height: 12),
                            Text(
                              'إجمالي: ${_fmt.format(total)} ر.ي',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: categoryItems,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    pieChartWidget,
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ...categoryItems,
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarChartSection(StatsLoaded state, StatsResult result) {
    final isWeek = state.timeframe == StatsTimeframe.week;

    final List<double> values = [];
    final List<String> labels = [];

    if (isWeek) {
      // 7 days
      final sortedEntries = result.dailySpendingWeek.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedEntries) {
        values.add(entry.value);
        labels.add(AppConstants.formatShortWeekday(entry.key));
      }
    } else {
      // All days of the target month (1..totalDaysInMonth)
      final sortedEntries = result.dailySpendingMonth.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedEntries) {
        values.add(entry.value);
        labels.add('${entry.key}');
      }
    }

    double maxY = 0;
    for (final v in values) {
      if (v > maxY) maxY = v;
    }
    if (maxY == 0) maxY = 1000;

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < values.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: values[i] > 0
                  ? AppTheme.primaryColor
                  : Colors.grey.shade300,
              width: isWeek ? 18 : 5,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text(
                'نمط الصرف اليومي',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              // Week / Month toggle
              SegmentedButton<StatsTimeframe>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: StatsTimeframe.week,
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('أسبوعي', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  ButtonSegment(
                    value: StatsTimeframe.month,
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('شهري', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
                selected: {state.timeframe},
                onSelectionChanged: (newSelection) {
                  context.read<StatsCubit>().switchTimeframe(
                    newSelection.first,
                  );
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.15,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey.shade900,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      final label = idx < labels.length ? labels[idx] : '';
                      final dayPrefix = isWeek ? label : 'يوم $label';
                      return BarTooltipItem(
                        '$dayPrefix\n${_fmt.format(rod.toY)} ر.ي',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          if (!isWeek) {
                            final dayNum = idx + 1;
                            if (dayNum != 1 &&
                                dayNum % 5 != 0 &&
                                dayNum != labels.length) {
                              return const SizedBox.shrink();
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              labels[idx],
                              style: TextStyle(
                                fontSize: isWeek ? 11 : 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletsBreakdown(BuildContext context, StatsResult result) {
    final walletsState = context.watch<WalletsCubit>().state;
    final wallets = walletsState is WalletsLoaded
        ? walletsState.wallets
        : <Wallet>[];

    if (wallets.isEmpty || result.walletExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المصروفات حسب المحافظ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...result.walletExpenses.entries.map((e) {
            final wallet = wallets.cast<Wallet?>().firstWhere(
              (w) => w?.id == e.key,
              orElse: () => null,
            );
            final name = wallet?.name ?? 'محفظة أخرى';
            final color = wallet != null
                ? Color(wallet.colorValue)
                : AppTheme.primaryColor;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color,
                    child: Icon(
                      wallet != null
                          ? AppConstants.getWalletIcon(wallet.iconCodePoint)
                          : Icons.wallet_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt.format(e.value)} ر.ي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
