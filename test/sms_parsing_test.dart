import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';

void main() {
  group('Real Yemeni Wallets SMS Parsing Tests (Step 6 Verification)', () {
    final testDate = DateTime(2026, 9, 6, 22, 10);

    test('Kuraimi Bank real SMS 1 — Salary/Deposit (Income 50,000.00)', () {
      const sender = 'KuraimiMB';
      const body = 'أودع/عادل عبدالواحد لحسابك50,000.00\n51,245.30YERرصيدك';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'income');
      expect(parsed.amount, 50000.0);
      expect(parsed.balance, 51245.30);
      expect(parsed.category, 'تحويل');
    });

    test('Kuraimi Bank real SMS 2 — Bill payment (Expense 400.00)', () {
      const sender = 'KuraimiMB';
      const body = 'تم سداد 400.00 جوال 772004664\nYER 2,545.30 رصيدك';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 400.0);
      expect(parsed.balance, 2545.30);
      expect(parsed.category, 'فواتير');
    });

    test('Kuraimi Bank real SMS 3 — Transfer out (Expense 1,100.00)', () {
      const sender = 'KuraimiIMB';
      const body = 'تم تحويل1,100.00لحساب خليل الرحمن\nرصيدك1,445.30YER';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 1100.0);
      expect(parsed.balance, 1445.30);
      expect(parsed.category, 'تحويل');
    });

    test('Kuraimi Bank real SMS 4 — Merchant Purchase (Expense 100.00)', () {
      const sender = 'KuraimiIMB';
      const body = 'تم خصم مبلغ YER 100.00 مقابل مشترياتك من 1588993\nالمرجع: 54177667';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 100.0);
      expect(parsed.balance, isNull);
      expect(parsed.category, 'بقالة');
    });

    test('Kuraimi Bank real SMS 5 — Multiline Deposit with مبلغ (Income 100.0)', () {
      const sender = 'KuraimiIMB';
      const body = 'أودع/ابراهيم عادل عبدالواحد الشرجبي\nلحسابك مبلغ 100 رصيدك YER 4045.3';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'income');
      expect(parsed.amount, 100.0);
      expect(parsed.balance, 4045.3);
      expect(parsed.isBalanceOnly, isFalse);
      expect(parsed.category, 'تحويل');
    });

    test('Kuraimi Bank real SMS 5b (User Case) — Deposit 500 with Balance 4045.3', () {
      const sender = 'Kuraimi';
      const body = 'أودع/ابراهيم عادل عبدالواحد الشرجبي\nلحسابك مبلغ 500 رصيدك YER 4045.3';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'income');
      expect(parsed.amount, 500.0); // Specifically verify amount is 500, NOT 4045!
      expect(parsed.balance, 4045.3);
      expect(parsed.isBalanceOnly, isFalse);
      expect(parsed.category, 'تحويل');
    });

    test('Kuraimi Bank Pure Balance Inquiry — Reconcile without fake income', () {
      const sender = 'Kuraimi';
      const body = 'رصيد حسابك في بنك الكريمي هو 3000 YER';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'adjustment');
      expect(parsed.amount, 0.0);
      expect(parsed.balance, 3000.0);
      expect(parsed.isBalanceOnly, isTrue);
    });

    test('Kuraimi Bank real SMS 6 — Mobile Bill payment (Expense 200.00)', () {
      const sender = 'KuraimiIMB';
      const body = 'تم سداد 200.00 جوال 772004664 رصيدك YER 51,045.30';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 200.0);
      expect(parsed.balance, 51045.30);
      expect(parsed.category, 'فواتير');
    });

    test('Jaib Wallet real SMS 1 — Transfer In (Income 500)', () {
      const sender = 'Jaib';
      const body = 'اضيف 500ر.ي تحويل مشترك\nرص:5680ر.ي من سام النزيلي-781563420';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'jeeb');
      expect(parsed.type, 'income');
      expect(parsed.amount, 500.0);
      expect(parsed.balance, 5680.0);
      expect(parsed.category, 'تحويل');
    });

    test('Jaib Wallet real SMS 2 — Mobile bill deduction (Expense 250)', () {
      const sender = 'Jaib';
      const body = 'خصم 250ر.ي رص:4330ر.ي للرقم 772004664 سداد يمن موبايل';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'jeeb');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 250.0);
      expect(parsed.balance, 4330.0);
      expect(parsed.category, 'فواتير');
    });

    test('Jaib Wallet real SMS 3 — Small deduction (Expense 100)', () {
      const sender = 'Jaib';
      const body = 'خصم 100ر.ي رص:4230ر.ي للرقم 772004664 سداد يمن موبايل';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'jeeb');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 100.0);
      expect(parsed.balance, 4230.0);
      expect(parsed.category, 'فواتير');
    });

    test('Deduplication fingerprint hash generates consistent key despite timestamp drift on same day', () {
      const sender = 'Jaib';
      const body = 'خصم 100ر.ي رص:4230ر.ي للرقم 772004664 سداد يمن موبايل';
      final key1 = SmsSenderRegistry.generateSmsKey(sender, testDate, body);
      final key2 = SmsSenderRegistry.generateSmsKey(sender, testDate, body);
      // Even if live listener got DateTime.now() 1 minute later than carrier SMS timestamp:
      final key3 = SmsSenderRegistry.generateSmsKey(sender, testDate.add(const Duration(minutes: 1)), body);
      // Different day produces different key:
      final key4 = SmsSenderRegistry.generateSmsKey(sender, testDate.add(const Duration(days: 1)), body);

      expect(key1, key2);
      expect(key1, key3); // Prevents timestamp drift duplication!
      expect(key1, isNot(key4));
    });

    test('User Real Case 1: Kuraimi Transfer 4100 with Suffix Balance 945.30YERرصيدك', () {
      const sender = 'Kuraimi';
      const body = 'تم تحويل4,100.00لحساب خليل الرحمن\n945.30YERرصيدك';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 4100.0);
      expect(parsed.balance, 945.30);
      expect(parsed.category, 'تحويل');
    });

    test('User Real Case 2: Kuraimi Deposit 1000 with Suffix Balance 5,045.30YERرصيدك', () {
      const sender = 'Kuraimi';
      const body = 'أودع/عادل عبدالواحد لحسابك1,000.00\n5,045.30YERرصيدك';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'income');
      expect(parsed.amount, 1000.0);
      expect(parsed.balance, 5045.30);
      expect(parsed.category, 'تحويل');
    });

    test('User Real Case 3: Kuraimi Purchase with Reference Number extraction', () {
      const sender = 'Kuraimi';
      const body = 'تم خصم مبلغ YER 100.00 مقابل مشترياتك من 1588993\nالمرجع: 54477347';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kuraimi');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 100.0);
      expect(parsed.referenceNumber, '54477347');
      expect(parsed.category, 'بقالة');

      // Verify reference number based key is 100% stable regardless of date
      final keyA = SmsSenderRegistry.generateSmsKey(sender, testDate, body);
      final keyB = SmsSenderRegistry.generateSmsKey(sender, testDate.add(const Duration(days: 30)), body);
      expect(keyA, keyB);
    });

    test('Unregistered/Personal SMS is skipped completely', () {
      const sender = '777123456';
      const body = 'السلام عليكم، كيف حالك أخي؟';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNull);
    });

    test('SMS Arrival timestamp preservation and formatting in Arabic', () {
      final arrivalTime = DateTime(2026, 9, 15, 20, 45); // 08:45 PM
      const sender = 'KuraimiMB';
      const body = 'أودع/عادل عبدالواحد لحسابك50,000.00\n51,245.30YERرصيدك';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: arrivalTime,
      );

      expect(parsed, isNotNull);
      expect(parsed!.date, arrivalTime);
      expect(parsed.date.hour, 20);
      expect(parsed.date.minute, 45);

      final formattedTime = AppConstants.formatTime(arrivalTime);
      expect(formattedTime.contains('08:45') || formattedTime.contains('8:45') || formattedTime.contains('٢٠:٤٥') || formattedTime.contains('٠٨:٤٥'), isTrue);

      final formattedDateTime = AppConstants.formatDateTime(arrivalTime);
      expect(formattedDateTime.contains('2026') || formattedDateTime.contains('٢٠٢٦'), isTrue);
    });

    test('formatTime morning AM formatting', () {
      final morningTime = DateTime(2026, 9, 15, 9, 15); // 09:15 AM
      final formattedTime = AppConstants.formatTime(morningTime);
      expect(formattedTime.contains('09:15') || formattedTime.contains('9:15') || formattedTime.contains('٠٩:١٥'), isTrue);
    });

    test('Jaib Wallet Pure Balance Inquiry — Reconcile without fake income', () {
      const sender = 'Jaib';
      const body = 'رصيدك: 5680 YER';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'jeeb');
      expect(parsed.type, 'adjustment');
      expect(parsed.amount, 0.0);
      expect(parsed.balance, 5680.0);
      expect(parsed.isBalanceOnly, isTrue);
    });

    test('Kash Wallet Deposit with Balance Disambiguation', () {
      const sender = 'Kash';
      const body = 'إيداع 1000 رصيدك YER 4000';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'kash');
      expect(parsed.type, 'income');
      expect(parsed.amount, 1000.0);
      expect(parsed.balance, 4000.0);
      expect(parsed.isBalanceOnly, isFalse);
    });

    test('Jawali Wallet Deduction with Balance Disambiguation', () {
      const sender = 'Jawali';
      const body = 'خصم 300 رصيدك: 2700';

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.walletType, 'jawali');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 300.0);
      expect(parsed.balance, 2700.0);
      expect(parsed.isBalanceOnly, isFalse);
    });

    test('Deduplication: TransactionRepository.deduplicateList collapses duplicate SMS transactions across varying timestamps', () {
      final tx1 = TransactionModel(
        id: 'uuid_1',
        walletId: 'kuraimi_1',
        type: 'expense',
        amount: 4100.0,
        category: 'تحويل',
        note: 'تم تحويل4,100.00لحساب خليل الرحمن\n945.30YERرصيدك',
        rawSmsBody: 'تم تحويل4,100.00لحساب خليل الرحمن\n945.30YERرصيدك',
        date: DateTime(2026, 9, 17, 1, 21),
        source: 'sms',
        createdAt: DateTime(2026, 9, 17, 1, 21),
      );

      final tx2 = TransactionModel(
        id: 'uuid_2',
        walletId: 'kuraimi_1',
        type: 'expense',
        amount: 4100.0,
        category: 'تحويل',
        note: 'تم تحويل4,100.00لحساب خليل الرحمن\n945.30YERرصيدك',
        rawSmsBody: 'تم تحويل4,100.00لحساب خليل الرحمن\n945.30YERرصيدك',
        date: DateTime(2026, 9, 17, 8, 45), // 7 hours later
        source: 'sms',
        createdAt: DateTime(2026, 9, 17, 8, 45),
      );

      final result = TransactionRepository.deduplicateList([tx1, tx2]);
      expect(result.length, 1);
      expect(result.first.id, 'uuid_1');
    });

    test('Deduplication: normalizeBodyForComparison matches despite whitespace or Arabic digits variations', () {
      final norm1 = TransactionRepository.normalizeBodyForComparison('تم تحويل4,100.00لحساب خليل الرحمن\n945.30YERرصيدك');
      final norm2 = TransactionRepository.normalizeBodyForComparison('تم تحويل 4,100.00 لحساب خليل الرحمن \r\n 945.30 YER رصيدك');
      expect(norm1, norm2);
    });
  });
}
