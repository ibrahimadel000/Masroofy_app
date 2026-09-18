import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/sms_service.dart';

class FakeWalletRepository extends WalletRepository {
  final Map<String, Wallet> _wallets = {};

  FakeWalletRepository([List<Wallet>? initial]) {
    if (initial != null) {
      for (final w in initial) {
        _wallets[w.id] = w;
      }
    }
  }

  @override
  List<Wallet> getWallets() => _wallets.values.toList();

  @override
  Wallet? getWalletById(String id) => _wallets[id];

  @override
  Future<void> saveWallet(Wallet wallet) async {
    _wallets[wallet.id] = wallet;
  }
}

class FakeTransactionRepository extends TransactionRepository {
  final List<TransactionModel> _txs = [];

  FakeTransactionRepository([List<TransactionModel>? initial]) {
    if (initial != null) {
      _txs.addAll(initial);
    }
  }

  void addTransaction(TransactionModel tx) => _txs.add(tx);

  @override
  List<TransactionModel> getTransactionsByWallet(String walletId) {
    final list = _txs.where((t) => t.walletId == walletId).toList();
    list.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }
}

void main() {
  group('Wallet Balance Reconciliation & Bank Truth Anchor Tests', () {
    late FakeWalletRepository walletRepo;
    late FakeTransactionRepository txRepo;
    const smsService = SmsService();

    setUp(() {
      final initialWallet = Wallet(
        id: 'kuraimi_wallet',
        name: 'الكريمي',
        type: 'kuraimi',
        colorValue: 0xFF006699,
        iconCodePoint: 0xe040,
        openingBalance: 0.0,
        createdAt: DateTime(2026, 9, 1),
      );
      walletRepo = FakeWalletRepository([initialWallet]);
      txRepo = FakeTransactionRepository();
    });

    test('1. Kuraimi deposit sets opening balance accurately to match bank statement', () async {
      // Day 1: Deposit of 50,000 with reported balance 51,245.30
      final depositTx = TransactionModel(
        id: 'tx_deposit',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 50000.0,
        category: 'تحويل',
        note: 'أودع/عادل عبدالواحد لحسابك50,000.00\n51,245.30YERرصيدك',
        date: DateTime(2026, 9, 15, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 15, 10, 0),
        rawSmsBody: 'أودع/عادل عبدالواحد لحسابك50,000.00\n51,245.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      );
      txRepo.addTransaction(depositTx);

      await smsService.reconcileWalletsWithLatestSms(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
      );

      final wallet = walletRepo.getWalletById('kuraimi_wallet')!;
      final txs = txRepo.getTransactionsByWallet('kuraimi_wallet');
      final liveBalance = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txs,
      );

      expect(liveBalance, 51245.30);
    });

    test('2. Kuraimi purchase (NO statement balance) deduces from wallet and is NOT wiped out by reconciliation', () async {
      // Step A: Setup history with Day 1 deposit
      final depositTx = TransactionModel(
        id: 'tx_deposit',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 50000.0,
        category: 'تحويل',
        note: 'أودع/عادل عبدالواحد لحسابك50,000.00\n51,245.30YERرصيدك',
        date: DateTime(2026, 9, 15, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 15, 10, 0),
        rawSmsBody: 'أودع/عادل عبدالواحد لحسابك50,000.00\n51,245.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      );
      txRepo.addTransaction(depositTx);

      await smsService.reconcileWalletsWithLatestSms(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
      );

      // Step B: User makes a purchase of 100.00 on Day 2 without a statement balance in SMS
      final purchaseTx = TransactionModel(
        id: 'tx_purchase_1',
        walletId: 'kuraimi_wallet',
        type: 'expense',
        amount: 100.0,
        category: 'مشتريات',
        note: 'تم خصم مبلغ YER 100.00 مقابل مشترياتك من 1588993\nالمرجع: 54177667',
        date: DateTime(2026, 9, 16, 14, 30),
        source: 'sms',
        createdAt: DateTime(2026, 9, 16, 14, 30),
        rawSmsBody: 'تم خصم مبلغ YER 100.00 مقابل مشترياتك من 1588993\nالمرجع: 54177667',
        rawSmsSender: 'KuraimiIMB',
      );
      txRepo.addTransaction(purchaseTx);

      // Verify wallet balance immediately after purchase
      var wallet = walletRepo.getWalletById('kuraimi_wallet')!;
      var txs = txRepo.getTransactionsByWallet('kuraimi_wallet');
      var balanceBeforeReconcile = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txs,
      );
      expect(balanceBeforeReconcile, 51145.30); // 51,245.30 - 100 = 51,145.30

      // Step C: Simulate app startup / resume / pull-to-refresh running reconcileWalletsWithLatestSms
      await smsService.reconcileWalletsWithLatestSms(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
      );

      wallet = walletRepo.getWalletById('kuraimi_wallet')!;
      txs = txRepo.getTransactionsByWallet('kuraimi_wallet');
      final balanceAfterReconcile = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txs,
      );

      // CRITICAL ASSERTION: Balance must remain 51,145.30 and NOT revert to 51,245.30!
      expect(balanceAfterReconcile, 51145.30);
    });

    test('3. Multiple consecutive purchases without balance statements all deduct sequentially', () async {
      // Day 1: Deposit (balance 51,245.30)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_deposit',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 50000.0,
        category: 'تحويل',
        note: 'أودع/عادل لحسابك50,000.00\n51,245.30YERرصيدك',
        date: DateTime(2026, 9, 15, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 15, 10, 0),
        rawSmsBody: 'أودع/عادل لحسابك50,000.00\n51,245.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      ));

      // Day 2: Purchase 1 (100)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_p1',
        walletId: 'kuraimi_wallet',
        type: 'expense',
        amount: 100.0,
        category: 'مشتريات',
        date: DateTime(2026, 9, 16, 12, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 16, 12, 0),
        rawSmsBody: 'تم خصم مبلغ YER 100.00 مقابل مشترياتك...',
        rawSmsSender: 'KuraimiIMB',
      ));

      // Day 3: Purchase 2 (200)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_p2',
        walletId: 'kuraimi_wallet',
        type: 'expense',
        amount: 200.0,
        category: 'مشتريات',
        date: DateTime(2026, 9, 17, 15, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 17, 15, 0),
        rawSmsBody: 'تم خصم مبلغ YER 200.00 مقابل مشترياتك...',
        rawSmsSender: 'KuraimiIMB',
      ));

      // Day 4: Purchase 3 (500)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_p3',
        walletId: 'kuraimi_wallet',
        type: 'expense',
        amount: 500.0,
        category: 'مشتريات',
        date: DateTime(2026, 9, 18, 9, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 18, 9, 0),
        rawSmsBody: 'تم خصم مبلغ YER 500.00 مقابل مشترياتك...',
        rawSmsSender: 'KuraimiIMB',
      ));

      await smsService.reconcileWalletsWithLatestSms(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
      );

      final wallet = walletRepo.getWalletById('kuraimi_wallet')!;
      final txs = txRepo.getTransactionsByWallet('kuraimi_wallet');
      final currentBalance = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txs,
      );

      // Expected: 51,245.30 - 100 - 200 - 500 = 50,445.30
      expect(currentBalance, 50445.30);
    });

    test('4. Subsequent deposit with new statement balance establishes a new truth anchor', () async {
      // Day 1: Deposit (balance 51,245.30)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_d1',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 50000.0,
        category: 'تحويل',
        note: 'أودع/عادل لحسابك50,000.00\n51,245.30YERرصيدك',
        date: DateTime(2026, 9, 15, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 15, 10, 0),
        rawSmsBody: 'أودع/عادل لحسابك50,000.00\n51,245.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      ));

      // Day 2: Purchase 800
      txRepo.addTransaction(TransactionModel(
        id: 'tx_p1',
        walletId: 'kuraimi_wallet',
        type: 'expense',
        amount: 800.0,
        category: 'مشتريات',
        date: DateTime(2026, 9, 16, 12, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 16, 12, 0),
        rawSmsBody: 'تم خصم مبلغ YER 800.00 مقابل مشترياتك...',
        rawSmsSender: 'KuraimiIMB',
      ));

      // Day 3: New deposit of 10,000 with reported bank balance: 51,245.30 - 800 + 10,000 = 60,445.30
      txRepo.addTransaction(TransactionModel(
        id: 'tx_d2',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 10000.0,
        category: 'تحويل',
        note: 'أودع/محمد لحسابك10,000.00\n60,445.30YERرصيدك',
        date: DateTime(2026, 9, 17, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 17, 10, 0),
        rawSmsBody: 'أودع/محمد لحسابك10,000.00\n60,445.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      ));

      // Day 4: Post-deposit purchase of 200 (no balance)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_p2',
        walletId: 'kuraimi_wallet',
        type: 'expense',
        amount: 200.0,
        category: 'مشتريات',
        date: DateTime(2026, 9, 18, 12, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 18, 12, 0),
        rawSmsBody: 'تم خصم مبلغ YER 200.00 مقابل مشترياتك...',
        rawSmsSender: 'KuraimiIMB',
      ));

      await smsService.reconcileWalletsWithLatestSms(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
      );

      final wallet = walletRepo.getWalletById('kuraimi_wallet')!;
      final txs = txRepo.getTransactionsByWallet('kuraimi_wallet');
      final currentBalance = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txs,
      );

      // Expected: 60,445.30 - 200 = 60,245.30
      expect(currentBalance, 60245.30);
    });

    test('5. Self-Healing: Bank deducted unrecorded 50 YER fee; next statement silently self-corrects balance', () async {
      // Day 1: Deposit (balance 51,245.30)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_d1',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 50000.0,
        category: 'تحويل',
        note: 'أودع/عادل لحسابك50,000.00\n51,245.30YERرصيدك',
        date: DateTime(2026, 9, 15, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 15, 10, 0),
        rawSmsBody: 'أودع/عادل لحسابك50,000.00\n51,245.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      ));

      // [Unrecorded bank fee of 50 occurs at the bank with no SMS sent]
      // Day 2: Deposit of 1,000 arrives, but bank statement balance is 52,195.30 (51,245.30 - 50 + 1000)
      txRepo.addTransaction(TransactionModel(
        id: 'tx_d2',
        walletId: 'kuraimi_wallet',
        type: 'income',
        amount: 1000.0,
        category: 'تحويل',
        note: 'أودع/سامي لحسابك1,000.00\n52,195.30YERرصيدك',
        date: DateTime(2026, 9, 16, 10, 0),
        source: 'sms',
        createdAt: DateTime(2026, 9, 16, 10, 0),
        rawSmsBody: 'أودع/سامي لحسابك1,000.00\n52,195.30YERرصيدك',
        rawSmsSender: 'KuraimiMB',
      ));

      await smsService.reconcileWalletsWithLatestSms(
        transactionRepository: txRepo,
        walletRepository: walletRepo,
      );

      final wallet = walletRepo.getWalletById('kuraimi_wallet')!;
      final txs = txRepo.getTransactionsByWallet('kuraimi_wallet');
      final currentBalance = BalanceCalculator.calculateWalletBalance(
        openingBalance: wallet.openingBalance,
        transactions: txs,
      );

      // Reconciled exactly to the bank's true balance: 52,195.30
      expect(currentBalance, 52195.30);
    });
  });
}
