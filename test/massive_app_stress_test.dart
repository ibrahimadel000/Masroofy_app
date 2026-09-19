import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/core/utils/smart_sms_parser.dart';
import 'package:mizaan/core/utils/stats_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/sms_service.dart';
import 'package:mizaan/features/sms/cubit/sms_cubit.dart';
import 'package:mizaan/features/sms/cubit/sms_state.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mizaan_massive_test_');
    Hive.init(tempDir.path);
    DatabaseService.markInitializedForTesting(true);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WalletAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    DatabaseService.markInitializedForTesting(false);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1. SMS Parsing Engine Massive Stress Tests', () {
    final testDate = DateTime(2026, 9, 19, 12, 0);

    test('Parses Arabic-Indic numerals with Arabic decimal separator (٫) and thousands separator (٬)', () {
      const sender = 'KuraimiMB';
      // Uses ٥٠٬٠٠٠٫٥٠ (50,000.50) and ٥١٬٢٤٥٫٧٥ (51,245.75)
      const body = 'أودع/عادل عبدالواحد لحسابك ٥٠٬٠٠٠٫٥٠ ر.ي\nرصيدك ٥١٬٢٤٥٫٧٥ ر.ي';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'income');
      expect(parsed.amount, 50000.50);
      expect(parsed.balance, 51245.75);
    });

    test('Handles extreme numbers: Very large amount (> 100M)', () {
      const sender = 'KuraimiMB';
      const body = 'تم إيداع مبلغ 125,500,000.50 YER لحسابك\nالرصيد الحالي 130,000,000.00 YER';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 125500000.50);
      expect(parsed.balance, 130000000.00);
      expect(parsed.type, 'income');
    });

    test('Handles decimal cents/fils precision (e.g. 0.25, 14.99)', () {
      const sender = 'KuraimiMB';
      const body = 'تم شراء بمبلغ 14.99 USD\nرصيدك 250.75 USD';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 14.99);
      expect(parsed.balance, 250.75);
      expect(parsed.type, 'expense');
    });

    test('Correctly extracts expanded reference numbers (Ref#, TRX, TXN, رقم القيد)', () {
      expect(SmsSenderRegistry.extractReferenceNumber('عملية شراء Ref# AB12984 ناجحة'), 'AB12984');
      expect(SmsSenderRegistry.extractReferenceNumber('حوالة واردة TRX: 99887722 رصيدك'), '99887722');
      expect(SmsSenderRegistry.extractReferenceNumber('تم السداد Txn: TXN776655 شكرا'), 'TXN776655');
      expect(SmsSenderRegistry.extractReferenceNumber('إيداع نقدي رقم القيد: 44556677'), '44556677');
      expect(SmsSenderRegistry.extractReferenceNumber('كود الحركة: MOV12345'), 'MOV12345');
    });

    test('SmartSmsParser analyzes universal international SMS across global currencies', () {
      // Test USD Bank SMS
      final usdResult = SmartSmsParser.analyzeSms(
        body: 'Your account was debited for USD 85.50 at Amazon. Current balance is USD 3,210.00.',
        sender: 'ChaseBank',
      );
      expect(usdResult.isSuccess, isTrue);
      expect(usdResult.type, 'expense');
      expect(usdResult.amount, 85.50);
      expect(usdResult.balance, 3210.00);
      expect(usdResult.currency, 'USD');

      // Test SAR Bank SMS
      final sarResult = SmartSmsParser.analyzeSms(
        body: 'تم إيداع راتب بمبلغ 8,500 ر.س في حسابك. الرصيد المتاح 12,300 ر.س',
        sender: 'AlRajhi',
      );
      expect(sarResult.isSuccess, isTrue);
      expect(sarResult.type, 'income');
      expect(sarResult.amount, 8500.0);
      expect(sarResult.balance, 12300.0);
      expect(sarResult.currency, 'ر.س');

      // Test EGP Bank SMS
      final egpResult = SmartSmsParser.analyzeSms(
        body: 'تم خصم مبلغ 450.00 EGP مشتريات كارفور. رصيد حسابك المتاح هو 5,120.00 EGP',
        sender: 'CIB',
      );
      expect(egpResult.isSuccess, isTrue);
      expect(egpResult.type, 'expense');
      expect(egpResult.amount, 450.0);
      expect(egpResult.balance, 5120.0);
      expect(egpResult.currency, 'EGP');
    });

    test('Non-financial and marketing spam SMS are safely rejected', () {
      final spam1 = SmsSenderRegistry.parseMessage(
        sender: 'SpamPromo',
        body: 'عرض خاص! اشترك الآن واحصل على 50% خصم على باقات الإنترنت. اتصل على 123',
        date: testDate,
      );
      expect(spam1, isNull);

      final spam2 = SmsSenderRegistry.parseMessage(
        sender: 'Verification',
        body: 'رمز التحقق الخاص بك هو 849201. لا تشارك هذا الرمز مع أي شخص.',
        date: testDate,
      );
      expect(spam2, isNull);
    });

    test('Deduplication correctly distinguishes distinct operations vs true duplicates', () {
      final txA = TransactionModel(
        id: 'tx_1',
        walletId: 'w_1',
        type: 'expense',
        amount: 500.0,
        category: 'أكل',
        date: testDate,
        source: 'sms',
        rawSmsBody: 'تم شراء بقيمة 500 مرجع 1111',
        createdAt: testDate,
      );

      final txBDistinctRef = TransactionModel(
        id: 'tx_2',
        walletId: 'w_1',
        type: 'expense',
        amount: 500.0,
        category: 'أكل',
        date: testDate,
        source: 'sms',
        rawSmsBody: 'تم شراء بقيمة 500 مرجع 2222',
        createdAt: testDate,
      );

      final txCExactDuplicateOfA = TransactionModel(
        id: 'tx_3',
        walletId: 'w_1',
        type: 'expense',
        amount: 500.0,
        category: 'أكل',
        date: testDate,
        source: 'sms',
        rawSmsBody: 'تم شراء بقيمة 500 مرجع 1111',
        createdAt: testDate.add(const Duration(minutes: 1)),
      );

      final deduplicated = TransactionRepository.deduplicateList([txA, txBDistinctRef, txCExactDuplicateOfA]);
      expect(deduplicated.length, 2);
      expect(deduplicated.map((t) => t.id).toList(), containsAll(['tx_1', 'tx_2']));
      expect(deduplicated.map((t) => t.id).toList(), isNot(contains('tx_3')));
    });
  });

  group('2. Financial Math & Multi-Currency Isolation Stress Tests', () {
    test('Calculates balance accurately with income, expense, and positive/negative adjustments', () {
      final txs = [
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'income',
          amount: 1000.0,
          category: 'راتب',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w1',
          type: 'expense',
          amount: 250.75,
          category: 'أكل',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '3',
          walletId: 'w1',
          type: 'adjustment',
          amount: -50.25, // downward adjustment
          category: 'تسوية',
          date: DateTime.now(),
          source: 'adjustment',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '4',
          walletId: 'w1',
          type: 'adjustment',
          amount: 100.0, // upward adjustment
          category: 'تسوية',
          date: DateTime.now(),
          source: 'adjustment',
          createdAt: DateTime.now(),
        ),
      ];

      // opening 5000 + 1000 - 250.75 - 50.25 + 100 = 5799.00
      final balance = BalanceCalculator.calculateWalletBalance(
        openingBalance: 5000.0,
        transactions: txs,
      );

      expect(balance, closeTo(5799.00, 0.001));
    });

    test('calculateTotalsByCurrency never sums across different currency codes', () {
      final wallets = [
        Wallet(
          id: 'w_yer',
          name: 'كريمي ريال يمني',
          type: 'kuraimi',
          colorValue: 0xFF000000,
          iconCodePoint: 0,
          openingBalance: 100000.0,
          currencyCode: 'YER',
          createdAt: DateTime.now(),
        ),
        Wallet(
          id: 'w_sar',
          name: 'الراجحي ريال سعودي',
          type: 'universal_bank',
          colorValue: 0xFF000000,
          iconCodePoint: 0,
          openingBalance: 5000.0,
          currencyCode: 'SAR',
          createdAt: DateTime.now(),
        ),
        Wallet(
          id: 'w_usd',
          name: 'حساب الدولار',
          type: 'universal_bank',
          colorValue: 0xFF000000,
          iconCodePoint: 0,
          openingBalance: 1200.0,
          currencyCode: 'USD',
          createdAt: DateTime.now(),
        ),
      ];

      final txs = [
        TransactionModel(
          id: 't1',
          walletId: 'w_yer',
          type: 'expense',
          amount: 20000.0,
          category: 'أكل',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: 't2',
          walletId: 'w_sar',
          type: 'income',
          amount: 1500.0,
          category: 'تحويل',
          date: DateTime.now(),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final totals = BalanceCalculator.calculateTotalsByCurrency(
        wallets: wallets,
        allTransactions: txs,
      );

      expect(totals['YER'], 80000.0);
      expect(totals['SAR'], 6500.0);
      expect(totals['USD'], 1200.0);
    });

    test('calculateTodaySpending strictly filters transactions within today boundary', () {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 8, 30);
      final todayNight = DateTime(now.year, now.month, now.day, 23, 15);
      final yesterdayNight = DateTime(now.year, now.month, now.day, 0, 0).subtract(const Duration(minutes: 5));
      final tomorrowMorning = DateTime(now.year, now.month, now.day, 23, 59, 59).add(const Duration(minutes: 5));

      final txs = [
        TransactionModel(
          id: '1',
          walletId: 'w1',
          type: 'expense',
          amount: 300.0,
          category: 'أكل',
          date: todayMorning,
          source: 'manual',
          createdAt: todayMorning,
        ),
        TransactionModel(
          id: '2',
          walletId: 'w1',
          type: 'expense',
          amount: 450.0,
          category: 'بقالة',
          date: todayNight,
          source: 'manual',
          createdAt: todayNight,
        ),
        TransactionModel(
          id: '3',
          walletId: 'w1',
          type: 'income', // ignored because it is income
          amount: 1000.0,
          category: 'راتب',
          date: todayMorning,
          source: 'manual',
          createdAt: todayMorning,
        ),
        TransactionModel(
          id: '4',
          walletId: 'w1',
          type: 'expense', // ignored because yesterday
          amount: 200.0,
          category: 'فواتير',
          date: yesterdayNight,
          source: 'manual',
          createdAt: yesterdayNight,
        ),
        TransactionModel(
          id: '5',
          walletId: 'w1',
          type: 'expense', // ignored because tomorrow
          amount: 500.0,
          category: 'تسوق',
          date: tomorrowMorning,
          source: 'manual',
          createdAt: tomorrowMorning,
        ),
      ];

      final todayTotal = BalanceCalculator.calculateTodaySpending(txs);
      expect(todayTotal, 750.0);
    });
  });

  group('3. Stats & Analytics Stress Tests', () {
    test('StatsCalculator handles empty transactions without division by zero or errors', () {
      final result = StatsCalculator.calculate(
        transactions: [],
        wallets: [],
        referenceDate: DateTime(2026, 9, 19),
      );

      expect(result.totalMonthlyExpense, 0.0);
      expect(result.totalMonthlyIncome, 0.0);
      expect(result.netSavings, 0.0);
      expect(result.dailyAverage, 0.0);
      expect(result.thisWeekExpense, 0.0);
      expect(result.lastWeekExpense, 0.0);
      expect(result.categorySpending, isEmpty);
      expect(result.hasEnoughData, isFalse);
    });

    test('StatsCalculator correctly calculates previous month boundary on January 1st', () {
      // Target: January 2026
      final refDate = DateTime(2026, 1, 15);
      final txs = [
        // Jan 2026 expense
        TransactionModel(
          id: 't_jan',
          walletId: 'w1',
          type: 'expense',
          amount: 1000.0,
          category: 'أكل',
          date: DateTime(2026, 1, 10),
          source: 'manual',
          createdAt: DateTime(2026, 1, 10),
        ),
        // Dec 2025 expense (previous month across year boundary)
        TransactionModel(
          id: 't_dec',
          walletId: 'w1',
          type: 'expense',
          amount: 800.0,
          category: 'أكل',
          date: DateTime(2025, 12, 20),
          source: 'manual',
          createdAt: DateTime(2025, 12, 20),
        ),
      ];

      final result = StatsCalculator.calculate(
        transactions: txs,
        wallets: [
          Wallet(
            id: 'w1',
            name: 'W1',
            type: 'other',
            colorValue: 0,
            iconCodePoint: 0,
            openingBalance: 0,
            createdAt: DateTime.now(),
          ),
        ],
        referenceDate: refDate,
      );

      expect(result.totalMonthlyExpense, 1000.0);
      expect(result.totalPrevMonthExpense, 800.0);
      // ((1000 - 800) / 800) * 100 = 25.0%
      expect(result.monthlyChangePercent, closeTo(25.0, 0.01));
    });

    test('StatsCalculator correctly filters by specific walletId', () {
      final txs = [
        TransactionModel(
          id: '1',
          walletId: 'w_A',
          type: 'expense',
          amount: 300.0,
          category: 'أكل',
          date: DateTime(2026, 9, 10),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          walletId: 'w_B',
          type: 'expense',
          amount: 700.0,
          category: 'تسوق',
          date: DateTime(2026, 9, 11),
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      final statsForA = StatsCalculator.calculate(
        transactions: txs,
        wallets: [],
        referenceDate: DateTime(2026, 9, 19),
        walletId: 'w_A',
      );

      expect(statsForA.totalMonthlyExpense, 300.0);
      expect(statsForA.categorySpending['أكل'], 300.0);
      expect(statsForA.categorySpending.containsKey('تسوق'), isFalse);
    });
  });

  group('4. Multi-Account Data Vault Isolation Tests', () {
    test('User A, User B, and Guest never share or leak database records', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Step 1: User A
      await DatabaseService.switchUser('user_alpha');
      final wRepoA = WalletRepository();
      final txRepoA = TransactionRepository();
      final wCubitA = WalletsCubit(repository: wRepoA);
      final txCubitA = TransactionsCubit(repository: txRepoA, prefs: prefs);

      await wCubitA.addWallet(
        name: 'محفظة ألفا',
        type: 'kuraimi',
        colorValue: 0xFF123456,
        iconCodePoint: 0xE000,
        openingBalance: 10000.0,
      );
      final walletAlphaId = (wCubitA.state as WalletsLoaded).wallets.first.id;
      await txCubitA.addTransaction(
        walletId: walletAlphaId,
        type: 'expense',
        amount: 200.0,
        category: 'أكل',
        date: DateTime.now(),
      );

      expect((wCubitA.state as WalletsLoaded).wallets.length, 1);
      expect((txCubitA.state as TransactionsLoaded).transactions.length, 1);

      // Step 2: Switch to User B
      await DatabaseService.switchUser('user_beta');
      final wRepoB = WalletRepository();
      final txRepoB = TransactionRepository();
      final wCubitB = WalletsCubit(repository: wRepoB);
      final txCubitB = TransactionsCubit(repository: txRepoB, prefs: prefs);

      // User B must start with zero wallets and zero transactions
      expect((wCubitB.state as WalletsLoaded).wallets, isEmpty);
      expect((txCubitB.state as TransactionsLoaded).transactions, isEmpty);

      // User B adds their own wallet
      await wCubitB.addWallet(
        name: 'محفظة بيتا',
        type: 'jeeb',
        colorValue: 0xFF654321,
        iconCodePoint: 0xE001,
        openingBalance: 50000.0,
      );
      expect((wCubitB.state as WalletsLoaded).wallets.length, 1);
      expect((wCubitB.state as WalletsLoaded).wallets.first.name, 'محفظة بيتا');

      // Step 3: Switch back to User A
      await DatabaseService.switchUser('user_alpha');
      final wCubitAAgain = WalletsCubit(repository: WalletRepository());
      final txCubitAAgain = TransactionsCubit(repository: TransactionRepository(), prefs: prefs);

      expect((wCubitAAgain.state as WalletsLoaded).wallets.length, 1);
      expect((wCubitAAgain.state as WalletsLoaded).wallets.first.name, 'محفظة ألفا');
      expect((txCubitAAgain.state as TransactionsLoaded).transactions.length, 1);
    });

    test('sanitizeUserId sanitizes all problematic characters safely', () {
      expect(DatabaseService.sanitizeUserId(null), 'guest');
      expect(DatabaseService.sanitizeUserId(''), 'guest');
      expect(DatabaseService.sanitizeUserId('   '), 'guest');
      expect(DatabaseService.sanitizeUserId('john.doe@gmail.com!'), 'john_doe_gmail_com_');
      expect(DatabaseService.sanitizeUserId('firebase-user-123_XYZ'), 'firebase-user-123_XYZ');
    });
  });

  group('5. Cubit Workflows and Selection Logic Stress Tests', () {
    test('SmsCubit toggles items, select-all, deselect-all, and reassigns target wallets', () {
      final fakeTxRepo = TransactionRepository();
      final cubit = SmsCubit(
        smsService: const SmsService(),
        transactionRepository: fakeTxRepo,
      );

      final candidate1 = SmsCandidateItem(
        data: ParsedSmsData(
          walletType: 'kuraimi',
          type: 'expense',
          amount: 100.0,
          category: 'أكل',
          date: DateTime.now(),
          rawSender: 'KuraimiMB',
          rawBody: 'test body 1',
          smsKey: 'k1',
        ),
        targetWalletId: 'w_1',
      );

      final candidate2 = SmsCandidateItem(
        data: ParsedSmsData(
          walletType: 'kuraimi',
          type: 'income',
          amount: 500.0,
          category: 'تحويل',
          date: DateTime.now(),
          rawSender: 'KuraimiMB',
          rawBody: 'test body 2',
          smsKey: 'k2',
        ),
        targetWalletId: 'w_1',
      );

      cubit.emit(SmsLoaded(items: [candidate1, candidate2], totalScanned: 2));

      // Test deselect all
      cubit.toggleSelectAll(false);
      var state = cubit.state as SmsLoaded;
      expect(state.items.every((i) => !i.isSelected), isTrue);

      // Test select all
      cubit.toggleSelectAll(true);
      state = cubit.state as SmsLoaded;
      expect(state.items.every((i) => i.isSelected), isTrue);

      // Test single toggle
      cubit.toggleSelect(0);
      state = cubit.state as SmsLoaded;
      expect(state.items[0].isSelected, isFalse);
      expect(state.items[1].isSelected, isTrue);

      // Test change target wallet
      cubit.setTargetWallet(0, 'w_new_wallet');
      state = cubit.state as SmsLoaded;
      expect(state.items[0].targetWalletId, 'w_new_wallet');
    });
  });
}
