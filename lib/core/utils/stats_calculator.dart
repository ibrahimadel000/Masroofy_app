import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

class StatsResult {
  final Map<String, double> categorySpending;
  final double totalMonthlyExpense;
  final double dailyAverage;
  final double thisWeekExpense;
  final double lastWeekExpense;
  final double? weeklyChangePercent;
  final String? topCategory;
  final double topCategoryAmount;
  final String? topWalletName;
  final double topWalletAmount;
  final double savingsPotential; // 10% of topCategoryAmount
  final Map<DateTime, double> dailySpendingWeek; // 7 days
  final Map<int, double> dailySpendingMonth; // day of month -> sum
  final bool hasEnoughData;

  const StatsResult({
    required this.categorySpending,
    required this.totalMonthlyExpense,
    required this.dailyAverage,
    required this.thisWeekExpense,
    required this.lastWeekExpense,
    this.weeklyChangePercent,
    this.topCategory,
    required this.topCategoryAmount,
    this.topWalletName,
    required this.topWalletAmount,
    required this.savingsPotential,
    required this.dailySpendingWeek,
    required this.dailySpendingMonth,
    required this.hasEnoughData,
  });
}

class StatsCalculator {
  /// Calculate all rule-based financial metrics given transactions and wallets.
  static StatsResult calculate({
    required List<TransactionModel> transactions,
    required List<Wallet> wallets,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final year = now.year;
    final month = now.month;

    // Filter monthly expenses
    final monthlyExpenses = transactions.where((tx) =>
        tx.type == 'expense' &&
        tx.date.year == year &&
        tx.date.month == month).toList();

    // 1. Spending by category
    final Map<String, double> categorySpending = {};
    double totalMonthlyExpense = 0.0;

    for (final tx in monthlyExpenses) {
      categorySpending[tx.category] = (categorySpending[tx.category] ?? 0.0) + tx.amount;
      totalMonthlyExpense += tx.amount;
    }

    // 2. Daily Average this month
    final daysElapsed = now.day > 0 ? now.day : 1;
    final dailyAverage = totalMonthlyExpense > 0 ? (totalMonthlyExpense / daysElapsed) : 0.0;

    // 3. Weekly spending comparison
    // thisWeek: last 7 calendar days up to end of today
    // lastWeek: 7 days prior to thisWeek
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startOfThisWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfThisWeek.subtract(const Duration(milliseconds: 1));

    double thisWeekExpense = 0.0;
    double lastWeekExpense = 0.0;

    for (final tx in transactions) {
      if (tx.type != 'expense') continue;
      if (!tx.date.isBefore(startOfThisWeek) && !tx.date.isAfter(endOfToday)) {
        thisWeekExpense += tx.amount;
      } else if (!tx.date.isBefore(startOfLastWeek) && !tx.date.isAfter(endOfLastWeek)) {
        lastWeekExpense += tx.amount;
      }
    }

    double? weeklyChangePercent;
    if (lastWeekExpense > 0) {
      weeklyChangePercent = ((thisWeekExpense - lastWeekExpense) / lastWeekExpense) * 100.0;
    } else if (thisWeekExpense > 0) {
      weeklyChangePercent = 100.0; // went from 0 to something
    } else {
      weeklyChangePercent = 0.0;
    }

    // 4. Top Category
    String? topCategory;
    double topCategoryAmount = 0.0;
    categorySpending.forEach((cat, amount) {
      if (amount > topCategoryAmount) {
        topCategoryAmount = amount;
        topCategory = cat;
      }
    });

    // 5. 10% saving suggestion
    final savingsPotential = topCategoryAmount * 0.10;

    // 6. Top Spending Wallet
    final Map<String, double> walletExpenses = {};
    for (final tx in monthlyExpenses) {
      walletExpenses[tx.walletId] = (walletExpenses[tx.walletId] ?? 0.0) + tx.amount;
    }

    String? topWalletName;
    double topWalletAmount = 0.0;
    final walletMap = {for (final w in wallets) w.id: w.name};

    walletExpenses.forEach((wId, amount) {
      if (amount > topWalletAmount) {
        topWalletAmount = amount;
        topWalletName = walletMap[wId] ?? 'محفظة';
      }
    });

    // 7. Daily spending for the 7 days of the week
    final Map<DateTime, double> dailySpendingWeek = {};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      dailySpendingWeek[day] = 0.0;
    }

    for (final tx in transactions) {
      if (tx.type != 'expense') continue;
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (dailySpendingWeek.containsKey(txDate)) {
        dailySpendingWeek[txDate] = (dailySpendingWeek[txDate] ?? 0.0) + tx.amount;
      }
    }

    // 8. Daily spending for the current month
    final Map<int, double> dailySpendingMonth = {};
    for (int d = 1; d <= now.day; d++) {
      dailySpendingMonth[d] = 0.0;
    }
    for (final tx in monthlyExpenses) {
      final d = tx.date.day;
      dailySpendingMonth[d] = (dailySpendingMonth[d] ?? 0.0) + tx.amount;
    }

    final hasEnoughData = transactions.any((tx) => tx.type == 'expense');

    return StatsResult(
      categorySpending: categorySpending,
      totalMonthlyExpense: totalMonthlyExpense,
      dailyAverage: dailyAverage,
      thisWeekExpense: thisWeekExpense,
      lastWeekExpense: lastWeekExpense,
      weeklyChangePercent: weeklyChangePercent,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      topWalletName: topWalletName,
      topWalletAmount: topWalletAmount,
      savingsPotential: savingsPotential,
      dailySpendingWeek: dailySpendingWeek,
      dailySpendingMonth: dailySpendingMonth,
      hasEnoughData: hasEnoughData,
    );
  }
}
