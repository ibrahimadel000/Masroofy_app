import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

void main() {
  group('Pure Balance Calculations Tests (plan.md Section 5)', () {
    test('walletBalance = openingBalance + Σ(income) − Σ(expense) ± Σ(adjustment)', () {
      final transactions = [
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'income',
          amount: 50000.0,
          category: 'راتب',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w1',
          type: 'expense',
          amount: 20000.0,
          category: 'بقالة',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final balance = BalanceCalculator.calculateWalletBalance(
        openingBalance: 150000.0,
        transactions: transactions,
      );

      // 150,000 + 50,000 - 20,000 = 180,000
      expect(balance, 180000.0);
    });

    test('walletBalance correctly applies positive and negative adjustments', () {
      final transactions = [
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'adjustment',
          amount: 5000.0, // positive delta
          category: 'تسوية',
          date: DateTime.now(),
          source: 'adjustment',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w1',
          type: 'adjustment',
          amount: -3000.0, // negative delta
          category: 'تسوية',
          date: DateTime.now(),
          source: 'adjustment',
          createdAt: DateTime.now(),
        ),
      ];

      final balance = BalanceCalculator.calculateWalletBalance(
        openingBalance: 50000.0,
        transactions: transactions,
      );

      // 50,000 + 5,000 - 3,000 = 52,000
      expect(balance, 52000.0);
    });

    test('totalBalance sums all wallet balances accurately', () {
      final wallets = [
        Wallet(
          id: 'w1',
          name: 'كاش',
          type: 'kash',
          colorValue: 0xFF0E7C61,
          iconCodePoint: 0xe000,
          openingBalance: 100000.0,
          createdAt: DateTime.now(),
        ),
        Wallet(
          id: 'w2',
          name: 'محفظتي',
          type: 'muhafazati',
          colorValue: 0xFF14A37F,
          iconCodePoint: 0xe001,
          openingBalance: 50000.0,
          createdAt: DateTime.now(),
        ),
      ];

      final transactions = [
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'income',
          amount: 25000.0,
          category: 'حوالة',
          date: DateTime.now(),
          source: 'sms',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w2',
          type: 'expense',
          amount: 10000.0,
          category: 'فواتير',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final total = BalanceCalculator.calculateTotalBalance(
        wallets: wallets,
        allTransactions: transactions,
      );

      // w1: 100,000 + 25,000 = 125,000
      // w2: 50,000 - 10,000 = 40,000
      // total: 165,000
      expect(total, 165000.0);
    });
  });

  group('Model Serialization Tests', () {
    test('Wallet toMap and fromMap serialize properly', () {
      final now = DateTime.now();
      final wallet = Wallet(
        id: 'test-w',
        name: 'جوالي',
        type: 'jawali',
        colorValue: 0xFFE5A93C,
        iconCodePoint: 1234,
        openingBalance: 75000.0,
        isFavorite: true,
        createdAt: now,
      );

      final map = wallet.toMap();
      final reconstituted = Wallet.fromMap(map);

      expect(reconstituted.id, wallet.id);
      expect(reconstituted.name, wallet.name);
      expect(reconstituted.type, wallet.type);
      expect(reconstituted.colorValue, wallet.colorValue);
      expect(reconstituted.openingBalance, wallet.openingBalance);
      expect(reconstituted.isFavorite, true);
    });

    test('TransactionModel toMap and fromMap serialize properly with SMS key', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx-1',
        walletId: 'w1',
        type: 'expense',
        amount: 3500.0,
        category: 'مواصلات',
        note: 'باص',
        date: now,
        source: 'sms',
        smsKey: 'hash-abc-123',
        createdAt: now,
      );

      final map = tx.toMap();
      final reconstituted = TransactionModel.fromMap(map);

      expect(reconstituted.id, tx.id);
      expect(reconstituted.walletId, tx.walletId);
      expect(reconstituted.type, 'expense');
      expect(reconstituted.amount, 3500.0);
      expect(reconstituted.source, 'sms');
      expect(reconstituted.smsKey, 'hash-abc-123');
    });

    test('TransactionModel preserves rawSmsBody and rawSmsSender in serialization', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx-sms',
        walletId: 'w1',
        type: 'expense',
        amount: 1500.0,
        category: 'تحويل',
        date: now,
        source: 'sms',
        rawSmsBody: 'تم تحويل مبلغ 1500 ريال بنجاح',
        rawSmsSender: 'Kuraimi',
        createdAt: now,
      );

      final map = tx.toMap();
      final reconstituted = TransactionModel.fromMap(map);

      expect(reconstituted.rawSmsBody, 'تم تحويل مبلغ 1500 ريال بنجاح');
      expect(reconstituted.rawSmsSender, 'Kuraimi');
    });

    test('Wallet supports currencyCode serialization and defaults to YER', () {
      final now = DateTime.now();
      final sarWallet = Wallet(
        id: 'w-sar',
        name: 'حساب سعودي',
        type: 'kuraimi',
        currencyCode: 'SAR',
        colorValue: 0xFF1B5E20,
        iconCodePoint: 1234,
        openingBalance: 1000.0,
        createdAt: now,
      );

      final map = sarWallet.toMap();
      final reconstituted = Wallet.fromMap(map);

      expect(reconstituted.currencyCode, 'SAR');

      // Test default to YER when currencyCode is missing from legacy map
      final legacyMap = Map<String, dynamic>.from(map)..remove('currencyCode');
      final legacyReconstituted = Wallet.fromMap(legacyMap);
      expect(legacyReconstituted.currencyCode, 'YER');
    });
  });

  group('Multi-Currency Grouping Tests (calculateTotalsByCurrency)', () {
    test('Calculates balance grouped by currency without cross-summing', () {
      final wallets = [
        Wallet(
          id: 'w-yer',
          name: 'كاش يمني',
          type: 'kash',
          currencyCode: 'YER',
          colorValue: 0xFF0E7C61,
          iconCodePoint: 0xe000,
          openingBalance: 200000.0,
          createdAt: DateTime.now(),
        ),
        Wallet(
          id: 'w-sar',
          name: 'كاش سعودي',
          type: 'kash',
          currencyCode: 'SAR',
          colorValue: 0xFF14A37F,
          iconCodePoint: 0xe001,
          openingBalance: 1500.0,
          createdAt: DateTime.now(),
        ),
        Wallet(
          id: 'w-usd',
          name: 'دولار',
          type: 'kuraimi',
          currencyCode: 'USD',
          colorValue: 0xFF2E7D32,
          iconCodePoint: 0xe002,
          openingBalance: 500.0,
          createdAt: DateTime.now(),
        ),
      ];

      final transactions = <TransactionModel>[
        // YER transactions
        TransactionModel(
          id: 'tx-yer-1',
          walletId: 'w-yer',
          type: 'income',
          amount: 50000.0,
          category: 'راتب',
          source: 'manual',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: 'tx-yer-2',
          walletId: 'w-yer',
          type: 'expense',
          amount: 20000.0,
          category: 'بقالة',
          source: 'manual',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        // SAR transactions
        TransactionModel(
          id: 'tx-sar-1',
          walletId: 'w-sar',
          type: 'expense',
          amount: 200.0,
          category: 'تسوق',
          source: 'manual',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      final totals = BalanceCalculator.calculateTotalsByCurrency(
        wallets: wallets,
        allTransactions: transactions,
      );

      // YER: 200,000 + 50,000 - 20,000 = 230,000
      expect(totals['YER'], 230000.0);
      // SAR: 1,500 - 200 = 1,300
      expect(totals['SAR'], 1300.0);
      // USD: 500 (no txs)
      expect(totals['USD'], 500.0);
    });
  });
}

