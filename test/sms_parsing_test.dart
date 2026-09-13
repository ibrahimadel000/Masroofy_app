import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/constants/sms_senders.dart';

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

    test('Deduplication fingerprint hash generates consistent sha256', () {
      const sender = 'Jaib';
      const body = 'خصم 100ر.ي رص:4230ر.ي للرقم 772004664 سداد يمن موبايل';
      final key1 = SmsSenderRegistry.generateSmsKey(sender, testDate, body);
      final key2 = SmsSenderRegistry.generateSmsKey(sender, testDate, body);
      final key3 = SmsSenderRegistry.generateSmsKey(sender, testDate.add(const Duration(seconds: 1)), body);

      expect(key1, key2);
      expect(key1, isNot(key3));
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
  });
}
