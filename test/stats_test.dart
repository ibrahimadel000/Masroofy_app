import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/utils/stats_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

void main() {
  group('StatsCalculator Tests (plan.md Step 7)', () {
    final refDate = DateTime(2026, 9, 13, 12, 0); // 13th of September 2026
    final w1 = Wallet(
      id: 'w1',
      name: 'كريمي كاش',
      type: 'kuraimi',
      colorValue: 0xFF0E7C61,
      iconCodePoint: 0xe000,
      openingBalance: 100000,
      createdAt: DateTime(2026, 1, 1),
    );
    final w2 = Wallet(
      id: 'w2',
      name: 'محفظة جيب',
      type: 'jaib',
      colorValue: 0xFF2E7D32,
      iconCodePoint: 0xe001,
      openingBalance: 50000,
      createdAt: DateTime(2026, 1, 1),
    );

    test('Computes empty state gracefully when no transactions exist', () {
      final res = StatsCalculator.calculate(
        transactions: [],
        wallets: [w1, w2],
        referenceDate: refDate,
      );

      expect(res.hasEnoughData, false);
      expect(res.totalMonthlyExpense, 0.0);
      expect(res.dailyAverage, 0.0);
      expect(res.topCategory, isNull);
      expect(res.savingsPotential, 0.0);
      expect(res.topWalletName, isNull);
    });

    test('Computes category spending, top category, and 10% savings suggestion accurately', () {
      final transactions = [
        // This month expenses
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'expense',
          amount: 25000,
          category: 'أكل',
          date: DateTime(2026, 9, 5),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w1',
          type: 'expense',
          amount: 15000,
          category: 'أكل',
          date: DateTime(2026, 9, 8),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '3',
          walletId: 'w2',
          type: 'expense',
          amount: 10000,
          category: 'فواتير',
          date: DateTime(2026, 9, 10),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        // Income should be excluded from expense stats
        TransactionModel(
          id: '4',
          walletId: 'w1',
          type: 'income',
          amount: 80000,
          category: 'راتب',
          date: DateTime(2026, 9, 1),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final res = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1, w2],
        referenceDate: refDate,
      );

      expect(res.hasEnoughData, true);
      expect(res.totalMonthlyExpense, 50000.0);
      expect(res.categorySpending['أكل'], 40000.0);
      expect(res.categorySpending['فواتير'], 10000.0);
      expect(res.topCategory, 'أكل');
      expect(res.topCategoryAmount, 40000.0);
      // 10% of 40,000 = 4,000
      expect(res.savingsPotential, 4000.0);
      // Daily average: 50,000 / 13 days
      expect(res.dailyAverage, closeTo(50000.0 / 13, 0.01));
      // Top wallet: w1 spent 40,000, w2 spent 10,000
      expect(res.topWalletName, 'كريمي كاش');
      expect(res.topWalletAmount, 40000.0);
    });

    test('Computes weekly spending comparison correctly ((thisWeek - lastWeek) / lastWeek)', () {
      // refDate is 2026-09-13
      // thisWeek: Sept 7 to Sept 13 (inclusive)
      // lastWeek: Aug 31 to Sept 6 (inclusive)
      final transactions = [
        // In thisWeek
        TransactionModel(
          id: 't1',
          walletId: 'w1',
          type: 'expense',
          amount: 12000,
          category: 'أكل',
          date: DateTime(2026, 9, 10),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        // In lastWeek
        TransactionModel(
          id: 't2',
          walletId: 'w1',
          type: 'expense',
          amount: 10000,
          category: 'أكل',
          date: DateTime(2026, 9, 3),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final res = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1],
        referenceDate: refDate,
      );

      expect(res.thisWeekExpense, 12000.0);
      expect(res.lastWeekExpense, 10000.0);
      // (12000 - 10000) / 10000 = +20%
      expect(res.weeklyChangePercent, closeTo(20.0, 0.01));
    });

    test('Weekly spending comparison detects decrease (-25%)', () {
      final transactions = [
        // In thisWeek: 7,500
        TransactionModel(
          id: 't1',
          walletId: 'w1',
          type: 'expense',
          amount: 7500,
          category: 'أكل',
          date: DateTime(2026, 9, 12),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        // In lastWeek: 10,000
        TransactionModel(
          id: 't2',
          walletId: 'w1',
          type: 'expense',
          amount: 10000,
          category: 'أكل',
          date: DateTime(2026, 9, 2),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final res = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1],
        referenceDate: refDate,
      );

      expect(res.thisWeekExpense, 7500.0);
      expect(res.lastWeekExpense, 10000.0);
      // (7500 - 10000) / 10000 = -25%
      expect(res.weeklyChangePercent, closeTo(-25.0, 0.01));
    });

    test('Computes past month daily average using full month days (e.g. 31 days for August)', () {
      final augDate = DateTime(2026, 8, 1);
      final transactions = [
        TransactionModel(
          id: 'aug1',
          walletId: 'w1',
          type: 'expense',
          amount: 31000,
          category: 'أكل',
          date: DateTime(2026, 8, 15),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final res = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1],
        referenceDate: augDate,
      );

      expect(res.totalMonthlyExpense, 31000.0);
      expect(res.totalDaysInMonth, 31);
      // Daily average for past completed month must divide by 31, NOT 1
      expect(res.dailyAverage, 1000.0);
      // All 31 days must be initialized in dailySpendingMonth
      expect(res.dailySpendingMonth.length, 31);
      expect(res.dailySpendingMonth[15], 31000.0);
      expect(res.dailySpendingMonth[1], 0.0);
      expect(res.dailySpendingMonth[31], 0.0);
    });

    test('Computes Month-over-Month comparison correctly', () {
      final septDate = DateTime(2026, 9, 13);
      final transactions = [
        // August expense: 20,000
        TransactionModel(
          id: 'aug1',
          walletId: 'w1',
          type: 'expense',
          amount: 20000,
          category: 'أكل',
          date: DateTime(2026, 8, 10),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        // September expense: 30,000 (+50%)
        TransactionModel(
          id: 'sep1',
          walletId: 'w1',
          type: 'expense',
          amount: 30000,
          category: 'أكل',
          date: DateTime(2026, 9, 5),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final res = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1],
        referenceDate: septDate,
      );

      expect(res.totalMonthlyExpense, 30000.0);
      expect(res.totalPrevMonthExpense, 20000.0);
      // (30000 - 20000) / 20000 = +50%
      expect(res.monthlyChangePercent, closeTo(50.0, 0.01));
    });

    test('Filters stats by specific wallet correctly', () {
      final transactions = [
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'expense',
          amount: 25000,
          category: 'أكل',
          date: DateTime(2026, 9, 5),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w2',
          type: 'expense',
          amount: 15000,
          category: 'فواتير',
          date: DateTime(2026, 9, 8),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      // Filter by w1 only
      final resW1 = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1, w2],
        referenceDate: refDate,
        walletId: 'w1',
      );

      expect(resW1.totalMonthlyExpense, 25000.0);
      expect(resW1.categorySpending.containsKey('فواتير'), false);
      expect(resW1.categorySpending['أكل'], 25000.0);

      // Filter by w2 only
      final resW2 = StatsCalculator.calculate(
        transactions: transactions,
        wallets: [w1, w2],
        referenceDate: refDate,
        walletId: 'w2',
      );

      expect(resW2.totalMonthlyExpense, 15000.0);
      expect(resW2.categorySpending.containsKey('أكل'), false);
      expect(resW2.categorySpending['فواتير'], 15000.0);
    });
  });
}
