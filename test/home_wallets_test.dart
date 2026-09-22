import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

class FakeWalletRepository implements WalletRepository {
  final Map<String, Wallet> _storage = {};

  @override
  List<Wallet> getWallets() => _storage.values.toList();

  @override
  Stream<List<Wallet>> watchWallets() => Stream.value(getWallets());

  @override
  Wallet? getWalletById(String id) => _storage[id];

  @override
  Future<void> saveWallet(Wallet wallet) async {
    _storage[wallet.id] = wallet;
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final w = _storage[id];
    if (w != null) {
      _storage[id] = w.copyWith(isFavorite: !w.isFavorite);
    }
  }

  @override
  Future<void> deleteWallet(String id) async {
    _storage.remove(id);
  }

  @override
  Future<void> syncFromFirestore() async {}
}

class FakeTransactionRepository implements TransactionRepository {
  final Map<String, TransactionModel> _storage = {};
  final Set<String> _smsKeys = {};

  @override
  List<TransactionModel> getTransactions() => _storage.values.toList();

  @override
  Stream<List<TransactionModel>> watchTransactions() => Stream.value(getTransactions());

  @override
  List<TransactionModel> getTransactionsByWallet(String walletId) =>
      _storage.values.where((tx) => tx.walletId == walletId).toList();

  @override
  bool hasSmsKey(String smsKey) => _smsKeys.contains(smsKey);

  @override
  Future<int> repairMisclassifiedSmsTransactions() async => 0;

  @override
  Future<void> saveSmsKey(String smsKey) async {
    _smsKeys.add(smsKey);
  }

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    _storage[transaction.id] = transaction;
    if (transaction.smsKey != null) {
      _smsKeys.add(transaction.smsKey!);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _storage.remove(id);
  }

  @override
  bool isDuplicateSms({
    required String smsKey,
    String? referenceNumber,
    String? rawSmsBody,
    required String walletId,
    required double amount,
    required String type,
    required DateTime date,
  }) {
    if (_smsKeys.contains(smsKey)) return true;
    for (final tx in _storage.values) {
      if (referenceNumber != null && tx.referenceNumber == referenceNumber) return true;
      if (tx.walletId == walletId && tx.type == type && (tx.amount - amount).abs() < 0.01) {
        if (tx.date.difference(date).abs().inHours <= 2) return true;
      }
    }
    return false;
  }

  @override
  Future<int> cleanDuplicateTransactions() async => 0;

  @override
  Future<void> syncFromFirestore() async {}
}

void main() {
  group('Step 4 — Home + Wallets + Transactions Integration Test', () {
    late FakeWalletRepository walletRepo;
    late FakeTransactionRepository txRepo;
    late WalletsCubit walletsCubit;
    late TransactionsCubit transactionsCubit;

    setUp(() {
      walletRepo = FakeWalletRepository();
      txRepo = FakeTransactionRepository();
      walletsCubit = WalletsCubit(repository: walletRepo);
      transactionsCubit = TransactionsCubit(repository: txRepo);
    });

    tearDown(() {
      walletsCubit.close();
      transactionsCubit.close();
    });

    test(
      'Done when: Add wallet (150,000) -> income 50,000 -> expense 20,000 -> wallet shows 180,000; totals update everywhere',
      () async {
        // 1. Add wallet with 150,000 opening balance
        await walletsCubit.addWallet(
          name: 'كاش',
          type: 'kash',
          colorValue: 0xFF0E7C61,
          iconCodePoint: 0xe000,
          openingBalance: 150000.0,
        );

        expect(walletsCubit.state, isA<WalletsLoaded>());
        final wallets = (walletsCubit.state as WalletsLoaded).wallets;
        expect(wallets.length, 1);
        final wallet = wallets.first;
        expect(wallet.name, 'كاش');
        expect(wallet.openingBalance, 150000.0);

        // Check initial balance before any transactions
        var liveBalance = BalanceCalculator.calculateWalletBalance(
          openingBalance: wallet.openingBalance,
          transactions: [],
        );
        expect(liveBalance, 150000.0);

        // 2. Add income 50,000
        await transactionsCubit.addTransaction(
          walletId: wallet.id,
          type: 'income',
          amount: 50000.0,
          category: 'راتب',
          date: DateTime.now(),
        );

        // 3. Add expense 20,000
        await transactionsCubit.addTransaction(
          walletId: wallet.id,
          type: 'expense',
          amount: 20000.0,
          category: 'بقالة',
          date: DateTime.now(),
        );

        expect(transactionsCubit.state, isA<TransactionsLoaded>());
        final txList = (transactionsCubit.state as TransactionsLoaded).transactions;
        expect(txList.length, 2);

        // 4. Verify wallet balance is 180,000
        final walletTxs = txList.where((tx) => tx.walletId == wallet.id).toList();
        liveBalance = BalanceCalculator.calculateWalletBalance(
          openingBalance: wallet.openingBalance,
          transactions: walletTxs,
        );
        expect(liveBalance, 180000.0);

        // 5. Verify total balance across all wallets is 180,000
        var totalBalance = BalanceCalculator.calculateTotalBalance(
          wallets: wallets,
          allTransactions: txList,
        );
        expect(totalBalance, 180000.0);

        // 6. Add second wallet (50,000) and verify total updates everywhere
        await walletsCubit.addWallet(
          name: 'محفظتي',
          type: 'muhafazati',
          colorValue: 0xFF14A37F,
          iconCodePoint: 0xe001,
          openingBalance: 50000.0,
        );

        final updatedWallets = (walletsCubit.state as WalletsLoaded).wallets;
        expect(updatedWallets.length, 2);

        totalBalance = BalanceCalculator.calculateTotalBalance(
          wallets: updatedWallets,
          allTransactions: txList,
        );
        // 180,000 (wallet 1) + 50,000 (wallet 2) = 230,000
        expect(totalBalance, 230000.0);
      },
    );

    test('Step 5 — Star toggle on wallet persists and updates state', () async {
      await walletsCubit.addWallet(
        name: 'جوالي',
        type: 'jawali',
        colorValue: 0xFF14A37F,
        iconCodePoint: 0xe001,
        openingBalance: 25000.0,
      );

      final wallet = (walletsCubit.state as WalletsLoaded).wallets.first;
      expect(wallet.isFavorite, false);

      // Toggle favorite -> ON
      await walletsCubit.toggleFavorite(wallet.id);
      final favorited = (walletsCubit.state as WalletsLoaded).wallets.first;
      expect(favorited.isFavorite, true);

      // Toggle favorite -> OFF
      await walletsCubit.toggleFavorite(wallet.id);
      final unfavorited = (walletsCubit.state as WalletsLoaded).wallets.first;
      expect(unfavorited.isFavorite, false);
    });

    test('Phase 1 — Update and Delete transaction updates state and balances', () async {
      await walletsCubit.addWallet(
        name: 'كاش',
        type: 'kash',
        colorValue: 0xFF0E7C61,
        iconCodePoint: 0xe000,
        openingBalance: 100000.0,
      );
      final wallet = (walletsCubit.state as WalletsLoaded).wallets.first;

      await transactionsCubit.addTransaction(
        walletId: wallet.id,
        type: 'expense',
        amount: 25000.0,
        category: 'بقالة',
        date: DateTime.now(),
        note: 'مشتريات قديمة',
      );

      var txList = (transactionsCubit.state as TransactionsLoaded).transactions;
      expect(txList.length, 1);
      final tx = txList.first;
      expect(tx.amount, 25000.0);
      expect(tx.note, 'مشتريات قديمة');

      // 1. Update transaction
      final updatedTx = tx.copyWith(
        amount: 30000.0,
        note: 'مشتريات معدلة',
      );
      await transactionsCubit.updateTransaction(updatedTx);

      txList = (transactionsCubit.state as TransactionsLoaded).transactions;
      expect(txList.length, 1);
      expect(txList.first.amount, 30000.0);
      expect(txList.first.note, 'مشتريات معدلة');

      // Verify balance reflects edit: 100,000 - 30,000 = 70,000
      var liveBalance = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txList,
      );
      expect(liveBalance, 70000.0);

      // 2. Delete transaction
      await transactionsCubit.deleteTransaction(tx.id);

      txList = (transactionsCubit.state as TransactionsLoaded).transactions;
      expect(txList.isEmpty, true);

      // Verify balance restored: 100,000
      liveBalance = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txList,
      );
      expect(liveBalance, 100000.0);
    });
  });
}

