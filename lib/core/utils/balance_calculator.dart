import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

class BalanceCalculator {
  /// Pure function: walletBalance = openingBalance + Σ(income) − Σ(expense) ± Σ(adjustment)
  static double calculateWalletBalance({
    required double openingBalance,
    required List<TransactionModel> transactions,
  }) {
    double balance = openingBalance;

    for (final tx in transactions) {
      switch (tx.type) {
        case 'income':
          balance += tx.amount;
          break;
        case 'expense':
          balance -= tx.amount;
          break;
        case 'adjustment':
          // Adjustment amount can be positive or negative
          balance += tx.amount;
          break;
      }
    }

    return balance;
  }

  /// Pure function: totalBalance = Σ walletBalance across all wallets (for backward-compatibility)
  static double calculateTotalBalance({
    required List<Wallet> wallets,
    required List<TransactionModel> allTransactions,
  }) {
    double total = 0.0;

    for (final wallet in wallets) {
      final walletTransactions =
          allTransactions.where((tx) => tx.walletId == wallet.id).toList();
      total += calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: walletTransactions,
      );
    }

    return total;
  }

  /// Returns wallet balances grouped by currency code (never mixes different currencies!)
  static Map<String, double> calculateTotalsByCurrency({
    required List<Wallet> wallets,
    required List<TransactionModel> allTransactions,
  }) {
    final Map<String, double> totals = {};
    for (final wallet in wallets) {
      final walletTransactions =
          allTransactions.where((tx) => tx.walletId == wallet.id).toList();
      final bal = calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: walletTransactions,
      );
      final curr = wallet.currencyCode;
      totals[curr] = (totals[curr] ?? 0.0) + bal;
    }
    return totals;
  }

  /// Calculate total spending for today
  static double calculateTodaySpending(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    double spending = 0.0;
    for (final tx in transactions) {
      if (tx.type == 'expense' &&
          tx.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
          tx.date.isBefore(todayEnd.add(const Duration(seconds: 1)))) {
        spending += tx.amount;
      }
    }
    return spending;
  }
}
