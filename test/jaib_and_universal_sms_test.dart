import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/services/sms_service.dart';

void main() {
  final testDate = DateTime(2026, 9, 19, 12, 0);

  group('Jaib & Universal SMS Parsing and Wallet Matching Tests', () {
    test('1. Jaib transfer with "تمت إضافة" and branded sender "Jaib"', () {
      const body = 'تمت إضافة مبلغ 5,000 ر.ي إلى محفظتك جيب. رصيدك الحالي: 15,000 ر.ي. مرجع: 1234567';
      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'Jaib',
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'income');
      expect(parsed.amount, 5000.0);
      expect(parsed.balance, 15000.0);
      expect(parsed.walletType, 'jeeb');
    });

    test('2. Jaib SMS from numeric shortcode "2020" detected via body', () {
      const body = 'عزيزي العميل، تمت إضافة مبلغ 10000 ريال إلى محفظتك جيب رصيدك: 25000 ريال';
      final template = SmsSenderRegistry.findTemplate('2020', null, body);
      expect(template, isNotNull);
      expect(template!.walletType, 'jeeb');

      final parsed = SmsSenderRegistry.parseMessage(
        sender: '2020',
        body: body,
        date: testDate,
      );
      expect(parsed, isNotNull);
      expect(parsed!.type, 'income');
      expect(parsed.amount, 10000.0);
      expect(parsed.balance, 25000.0);
    });

    test('3. Jaib transfer with "تم استلام حوالة" and reference number', () {
      const body = 'تم استلام حوالة بمبلغ 2500 ر.ي من محفظة جيب رقم العملية 888999 رصيدك 7500';
      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'TIB-SMS',
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'income');
      expect(parsed.amount, 2500.0);
      expect(parsed.balance, 7500.0);
      expect(parsed.walletType, 'jeeb');
    });

    test('4. Jaib expense with "تم تحويل مبلغ" (outward transfer)', () {
      const body = 'تم تحويل مبلغ 3,000 ر.ي إلى 777123456 رصيدك: 4,500 ر.ي';
      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'Jaib',
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'expense');
      expect(parsed.amount, 3000.0);
      expect(parsed.balance, 4500.0);
      expect(parsed.walletType, 'jeeb');
    });

    test('5. Jaib purchase with "تم خصم" and merchant name', () {
      const body = 'تم خصم مبلغ 1,500 ر.ي سداد فاتورة يمن موبايل رصيدك 8,500';
      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'بنك التضامن',
        body: body,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'expense');
      expect(parsed.amount, 1500.0);
      expect(parsed.balance, 8500.0);
    });

    test('6. Unlisted bank / Exchange SMS via Universal Bank template', () {
      const body = 'تم استلام حوالة بمبلغ 50000 ريال من صرافة النجم مرجع 998877 رصيد حسابك 120000';
      final template = SmsSenderRegistry.findTemplate('AL-NAJM', null, body);
      expect(template, isNotNull);
      expect(template!.walletType, 'universal_bank');

      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'AL-NAJM',
        body: body,
        date: testDate,
      );
      expect(parsed, isNotNull);
      expect(parsed!.type, 'income');
      expect(parsed.amount, 50000.0);
      expect(parsed.balance, 120000.0);
    });

    test('7. Smart Wallet Matching for Jaib wallet', () {
      final List<Wallet> userWallets = [
        Wallet(
          id: 'w1',
          name: 'حساب بنك الكريمي',
          type: 'kuraimi',
          currencyCode: 'YER',
          colorValue: 0xFF1E88E5,
          iconCodePoint: 0xE84F,
          openingBalance: 1000,
          createdAt: DateTime.now(),
        ),
        Wallet(
          id: 'w2',
          name: 'محفظة جيب التضامن',
          type: 'jeeb',
          currencyCode: 'YER',
          colorValue: 0xFF43A047,
          iconCodePoint: 0xE84F,
          openingBalance: 500,
          createdAt: DateTime.now(),
        ),
      ];

      final template = SmsSenderRegistry.findTemplate('Jaib');
      final matched = SmsService.findMatchingWallet(
        userWallets: userWallets,
        walletType: 'jeeb',
        template: template,
      );

      expect(matched, isNotNull);
      expect(matched!.id, 'w2');
      expect(matched.name, 'محفظة جيب التضامن');
    });

    test('8. Universal bank matches favorite or first wallet', () {
      final List<Wallet> userWallets = [
        Wallet(
          id: 'w1',
          name: 'المحفظة الرئيسية',
          type: 'cash',
          currencyCode: 'YER',
          colorValue: 0xFF1E88E5,
          iconCodePoint: 0xE84F,
          openingBalance: 1000,
          isFavorite: true,
          createdAt: DateTime.now(),
        ),
      ];

      final template = SmsSenderRegistry.findTemplate('UnknownBank', null, 'تم إيداع 5000 ريال');
      final matched = SmsService.findMatchingWallet(
        userWallets: userWallets,
        walletType: template?.walletType ?? 'universal_bank',
        template: template,
      );

      expect(matched, isNotNull);
      expect(matched!.id, 'w1');
    });
  });
}
