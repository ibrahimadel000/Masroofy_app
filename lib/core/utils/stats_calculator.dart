import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

class StatsResult {
  final Map<String, double> categorySpending;
  final double totalMonthlyExpense;
  final double totalMonthlyIncome;
  final double netSavings;
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
  final Map<String, double> walletExpenses;
  final Map<String, double> categoryIncome;
  final int monthlyTransactionCount;
  final bool hasEnoughData;
  final double totalPrevMonthExpense;
  final double? monthlyChangePercent;
  final Map<String, int> categoryExpenseCount;
  final Map<String, int> categoryIncomeCount;
  final int totalDaysInMonth;
  final int daysElapsed;
  final bool isCurrentMonth;

  const StatsResult({
    required this.categorySpending,
    required this.totalMonthlyExpense,
    this.totalMonthlyIncome = 0.0,
    this.netSavings = 0.0,
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
    this.walletExpenses = const {},
    this.categoryIncome = const {},
    this.monthlyTransactionCount = 0,
    required this.hasEnoughData,
    this.totalPrevMonthExpense = 0.0,
    this.monthlyChangePercent,
    this.categoryExpenseCount = const {},
    this.categoryIncomeCount = const {},
    this.totalDaysInMonth = 30,
    this.daysElapsed = 1,
    this.isCurrentMonth = true,
  });
}

class StatsCalculator {
  /// Calculate all rule-based financial metrics given transactions and wallets.
  static StatsResult calculate({
    required List<TransactionModel> transactions,
    required List<Wallet> wallets,
    DateTime? referenceDate,
    String? walletId,
  }) {
    // 1. Optional wallet filter
    final filteredTransactions = walletId == null
        ? transactions
        : transactions.where((tx) => tx.walletId == walletId).toList();

    final now = referenceDate ?? DateTime.now();
    final year = now.year;
    final month = now.month;

    // Check if the target month is the ongoing calendar month
    final realNow = DateTime.now();
    final isCurrentMonth = (year == realNow.year && month == realNow.month);

    // Total days in target month (e.g. 31 in Aug, 30 in Sep, 28/29 in Feb)
    final totalDaysInMonth = DateTime(year, month + 1, 0).day;

    // Days elapsed so far in this month:
    // If it's a past month, the full month has completed (totalDaysInMonth).
    // If it's the current month, use today's day (or referenceDate.day if explicitly specified).
    final int daysElapsed;
    if (isCurrentMonth) {
      daysElapsed = (referenceDate != null && referenceDate.day > 0)
          ? referenceDate.day
          : (realNow.day > 0 ? realNow.day : 1);
    } else {
      daysElapsed = totalDaysInMonth;
    }

    // Filter monthly expenses and incomes for target month
    final monthlyExpenses = filteredTransactions
        .where(
          (tx) =>
              tx.type == 'expense' &&
              tx.date.year == year &&
              tx.date.month == month,
        )
        .toList();

    final monthlyIncomes = filteredTransactions
        .where(
          (tx) =>
              tx.type == 'income' &&
              tx.date.year == year &&
              tx.date.month == month,
        )
        .toList();

    final monthlyTotalCount = monthlyExpenses.length + monthlyIncomes.length;

    // 1. Spending by category & count
    final Map<String, double> categorySpending = {};
    final Map<String, int> categoryExpenseCount = {};
    double totalMonthlyExpense = 0.0;

    for (final tx in monthlyExpenses) {
      categorySpending[tx.category] =
          (categorySpending[tx.category] ?? 0.0) + tx.amount;
      categoryExpenseCount[tx.category] =
          (categoryExpenseCount[tx.category] ?? 0) + 1;
      totalMonthlyExpense += tx.amount;
    }

    // 1.b Income by category & count & total income
    final Map<String, double> categoryIncome = {};
    final Map<String, int> categoryIncomeCount = {};
    double totalMonthlyIncome = 0.0;

    for (final tx in monthlyIncomes) {
      categoryIncome[tx.category] =
          (categoryIncome[tx.category] ?? 0.0) + tx.amount;
      categoryIncomeCount[tx.category] =
          (categoryIncomeCount[tx.category] ?? 0) + 1;
      totalMonthlyIncome += tx.amount;
    }

    final double netSavings = totalMonthlyIncome - totalMonthlyExpense;

    // 2. Daily Average this month
    final dailyAverage = totalMonthlyExpense > 0
        ? (totalMonthlyExpense / (daysElapsed > 0 ? daysElapsed : 1))
        : 0.0;

    // 2.b Previous Month comparison (Month-over-Month)
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    final prevMonthExpenses = filteredTransactions
        .where(
          (tx) =>
              tx.type == 'expense' &&
              tx.date.year == prevYear &&
              tx.date.month == prevMonth,
        )
        .toList();

    double totalPrevMonthExpense = 0.0;
    for (final tx in prevMonthExpenses) {
      totalPrevMonthExpense += tx.amount;
    }

    double? monthlyChangePercent;
    if (totalPrevMonthExpense > 0) {
      monthlyChangePercent =
          ((totalMonthlyExpense - totalPrevMonthExpense) /
              totalPrevMonthExpense) *
          100.0;
    } else if (totalMonthlyExpense > 0) {
      monthlyChangePercent = 100.0;
    } else {
      monthlyChangePercent = 0.0;
    }

    // 3. Weekly spending comparison
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startOfThisWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfThisWeek.subtract(
      const Duration(milliseconds: 1),
    );

    double thisWeekExpense = 0.0;
    double lastWeekExpense = 0.0;

    for (final tx in filteredTransactions) {
      if (tx.type != 'expense') continue;
      if (!tx.date.isBefore(startOfThisWeek) && !tx.date.isAfter(endOfToday)) {
        thisWeekExpense += tx.amount;
      } else if (!tx.date.isBefore(startOfLastWeek) &&
          !tx.date.isAfter(endOfLastWeek)) {
        lastWeekExpense += tx.amount;
      }
    }

    double? weeklyChangePercent;
    if (lastWeekExpense > 0) {
      weeklyChangePercent =
          ((thisWeekExpense - lastWeekExpense) / lastWeekExpense) * 100.0;
    } else if (thisWeekExpense > 0) {
      weeklyChangePercent = 100.0;
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
      walletExpenses[tx.walletId] =
          (walletExpenses[tx.walletId] ?? 0.0) + tx.amount;
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
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      dailySpendingWeek[day] = 0.0;
    }

    for (final tx in filteredTransactions) {
      if (tx.type != 'expense') continue;
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (dailySpendingWeek.containsKey(txDate)) {
        dailySpendingWeek[txDate] =
            (dailySpendingWeek[txDate] ?? 0.0) + tx.amount;
      }
    }

    // 8. Daily spending for the entire month (all days 1..totalDaysInMonth)
    final Map<int, double> dailySpendingMonth = {};
    for (int d = 1; d <= totalDaysInMonth; d++) {
      dailySpendingMonth[d] = 0.0;
    }
    for (final tx in monthlyExpenses) {
      final d = tx.date.day;
      if (d >= 1 && d <= totalDaysInMonth) {
        dailySpendingMonth[d] = (dailySpendingMonth[d] ?? 0.0) + tx.amount;
      }
    }

    final hasEnoughData = filteredTransactions.any(
      (tx) => tx.type == 'expense' || tx.type == 'income',
    );

    return StatsResult(
      categorySpending: categorySpending,
      totalMonthlyExpense: totalMonthlyExpense,
      totalMonthlyIncome: totalMonthlyIncome,
      netSavings: netSavings,
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
      walletExpenses: walletExpenses,
      categoryIncome: categoryIncome,
      monthlyTransactionCount: monthlyTotalCount,
      hasEnoughData: hasEnoughData,
      totalPrevMonthExpense: totalPrevMonthExpense,
      monthlyChangePercent: monthlyChangePercent,
      categoryExpenseCount: categoryExpenseCount,
      categoryIncomeCount: categoryIncomeCount,
      totalDaysInMonth: totalDaysInMonth,
      daysElapsed: daysElapsed,
      isCurrentMonth: isCurrentMonth,
    );
  }
}
