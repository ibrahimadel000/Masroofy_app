import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mizaan/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStats();
    });
  }

  void _refreshStats() {
    final txState = context.read<TransactionsCubit>().state;
    final wState = context.read<WalletsCubit>().state;
    final transactions = txState is TransactionsLoaded ? txState.transactions : <TransactionModel>[];
    final wallets = wState is WalletsLoaded ? wState.wallets : <Wallet>[];
    context.read<StatsCubit>().updateData(transactions: transactions, wallets: wallets);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'أكل':
        return Colors.orange.shade700;
      case 'مواصلات':
        return Colors.blue.shade600;
      case 'بقالة':
        return Colors.green.shade600;
      case 'فواتير':
        return Colors.red.shade500;
      case 'تحويل':
        return Colors.purple.shade600;
      case 'راتب':
        return Colors.teal.shade600;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'أكل':
        return Icons.restaurant_rounded;
      case 'مواصلات':
        return Icons.directions_bus_rounded;
      case 'بقالة':
        return Icons.shopping_basket_rounded;
      case 'فواتير':
        return Icons.receipt_long_rounded;
      case 'تحويل':
        return Icons.swap_horiz_rounded;
      case 'راتب':
        return Icons.payments_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in Transactions or Wallets to keep Stats in sync
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
          return const Center(child: CircularProgressIndicator());
        }

        if (state is StatsError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (state is! StatsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final result = state.result;

        if (!result.hasEnoughData) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshStats(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Month Header
                _buildMonthHeader(state.selectedMonth),
                const SizedBox(height: 16),

                // 2. Rule-based Insight Cards (Step 7 requirement)
                _buildInsightCards(result),
                const SizedBox(height: 20),

                // 3. Category Pie Chart
                _buildCategoryPieSection(result),
                const SizedBox(height: 20),

                // 4. Daily Spending Bar Chart (Week / Month toggle)
                _buildBarChartSection(state, result),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد بيانات كافية بعد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'سجّل حركاتك ومصروفاتك اليومية أو استوردها من رسائل المحافظ لتظهر لك الرسوم البيانية والتحليلات المالية الذكية.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('➕ إضافة حركة الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    final monthName = DateFormat('MMMM yyyy', 'ar').format(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor),
          Text(
            monthName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'الشهر الحالي',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCards(StatsResult result) {
    return Column(
      children: [
        // Card 1: Weekly Spending Comparison (صرفك زاد/نقص X%)
        if (result.weeklyChangePercent != null) ...[
          _buildWeeklyComparisonCard(result),
          const SizedBox(height: 12),
        ],

        // Row of Daily Average & Top Wallet
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'المعدل اليومي',
                value: '${_fmt.format(result.dailyAverage)} ر.ي',
                subtitle: 'لهذا الشهر',
                icon: Icons.speed_rounded,
                iconColor: Colors.blue.shade600,
                bgColor: Colors.blue.shade50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'أكثر محفظة صرفاً',
                value: result.topWalletName ?? '—',
                subtitle: '${_fmt.format(result.topWalletAmount)} ر.ي',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.purple.shade600,
                bgColor: Colors.purple.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Card 2: 10% Smart Saving Suggestion
        if (result.topCategory != null && result.savingsPotential > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade700,
                  Colors.teal.shade900,
                ],
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
                  child: const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 28),
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
        : (isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    final String titleText = isIdentical
        ? 'صرفك متطابق مع الأسبوع الماضي'
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
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
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
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildCategoryPieSection(StatsResult result) {
    final entries = result.categorySpending.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    final total = result.totalMonthlyExpense;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'توزيع المصروفات بالتصنيف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
          const SizedBox(height: 20),

          // Donut Pie Chart
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: entries.map((entry) {
                  final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
                  final color = _getCategoryColor(entry.key);
                  return PieChartSectionData(
                    value: entry.value,
                    title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                    color: color,
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend list
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: entries.map((entry) {
              final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
              final color = _getCategoryColor(entry.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(entry.key),
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.key} (${pct.toStringAsFixed(0)}% - ${_fmt.format(entry.value)} ر.ي)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
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
        labels.add(DateFormat('E', 'ar').format(entry.key));
      }
    } else {
      // Month days
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
              color: values[i] > 0 ? AppTheme.primaryColor : Colors.grey.shade300,
              width: isWeek ? 18 : 6,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نمط الصرف اليومي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              // Week / Month toggle
              SegmentedButton<StatsTimeframe>(
                segments: const [
                  ButtonSegment(
                    value: StatsTimeframe.week,
                    label: Text('أسبوعي', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: StatsTimeframe.month,
                    label: Text('شهري', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {state.timeframe},
                onSelectionChanged: (newSelection) {
                  context.read<StatsCubit>().switchTimeframe(newSelection.first);
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
                      return BarTooltipItem(
                        '$label\n${_fmt.format(rod.toY)} ر.ي',
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
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          // In month mode, show every 5th label to prevent clutter
                          if (!isWeek && idx % 5 != 0 && idx != labels.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              labels[idx],
                              style: TextStyle(
                                fontSize: isWeek ? 11 : 10,
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
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
}
