import 'package:flutter_test/flutter_test.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/core/utils/smart_sms_parser.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/services/sms_service.dart';

void main() {
  final testDate = DateTime(2026, 9, 15, 14, 30);

  group('Smart Universal SMS Parser Tests (Worldwide Banks & Wallets)', () {
    test('1. Saudi Arabia (Al Rajhi Bank) — Expense with Balance Disambiguation', () {
      const raw = 'تم سداد مبلغ 250.00 ر.س من حسابك. الرصيد الحالي 4,150.00 ر.س.';
      final result = SmartSmsParser.analyzeSms(body: raw, sender: 'ALRAJHI');

      expect(result.isSuccess, isTrue);
      expect(result.type, 'expense');
      expect(result.amount, 250.0);
      expect(result.balance, 4150.0);
      expect(result.currency, 'ر.س');
      expect(result.isBalanceOnly, isFalse);
    });

    test('2. United Arab Emirates (Emirates NBD) — English Debit with Balance', () {
      const raw = 'Debit AED 350.00 from card ending 1234 at Carrefour. Available balance is AED 12,450.00.';
      final result = SmartSmsParser.analyzeSms(body: raw, sender: 'EmiratesNBD');

      expect(result.isSuccess, isTrue);
      expect(result.type, 'expense');
      expect(result.amount, 350.0);
      expect(result.balance, 12450.0);
      expect(result.currency, 'AED');
      expect(result.isBalanceOnly, isFalse);
    });

    test('3. Egypt (CIB / Vodafone Cash) — Inward Transfer with Balance', () {
      const raw = 'تم استلام تحويل بمبلغ 2,500.00 ج.م على محفظتك. الرصيد المتاح 5,200.00 ج.م.';
      final result = SmartSmsParser.analyzeSms(body: raw, sender: 'VodafoneCash');

      expect(result.isSuccess, isTrue);
      expect(result.type, 'income');
      expect(result.amount, 2500.0);
      expect(result.balance, 5200.0);
      expect(result.currency, 'ج.م');
      expect(result.isBalanceOnly, isFalse);
    });

    test('4. Kuwait (NBK / Boubyan) — KWD Deduction with Balance', () {
      const raw = 'تم خصم 25.500 د.ك من حسابك. الرصيد: 350.000 د.ك.';
      final result = SmartSmsParser.analyzeSms(body: raw, sender: 'NBK');

      expect(result.isSuccess, isTrue);
      expect(result.type, 'expense');
      expect(result.amount, 25.5);
      expect(result.balance, 350.0);
      expect(result.currency, 'د.ك');
      expect(result.isBalanceOnly, isFalse);
    });

    test('5. International / USA (Chase) — English Purchase with Balance', () {
      const raw = r'Chase: You made a purchase of $45.20 at Starbucks. Avail Bal: $1,254.80.';
      final result = SmartSmsParser.analyzeSms(body: raw, sender: 'Chase');

      expect(result.isSuccess, isTrue);
      expect(result.type, 'expense');
      expect(result.amount, 45.20);
      expect(result.balance, 1254.80);
      expect(result.currency, r'$');
      expect(result.isBalanceOnly, isFalse);
    });

    test('6. International Pure Balance Inquiry — USD Account', () {
      const raw = 'Your available balance for account ending in 9876 is USD 3,500.00';
      final result = SmartSmsParser.analyzeSms(body: raw, sender: 'BankOfAmerica');

      expect(result.isSuccess, isTrue);
      expect(result.type, 'adjustment');
      expect(result.amount, 0.0);
      expect(result.balance, 3500.0);
      expect(result.isBalanceOnly, isTrue);
      expect(result.currency, 'USD');
    });

    test('7. Dynamic Template Generation & Registration Workflow', () {
      // User pastes an SMS from a new bank (e.g. "QNB" in Qatar)
      const qnbSms = 'تم إيداع مبلغ 1000.00 ر.ق في حسابك. الرصيد المتاح 8500.00 ر.ق.';
      final analysis = SmartSmsParser.analyzeSms(
        body: qnbSms,
        sender: 'QNB',
        customWalletName: 'بنك قطر الوطني',
      );

      expect(analysis.isSuccess, isTrue);
      expect(analysis.generatedTemplate, isNotNull);

      // Register the generated template dynamically in the registry
      final generatedTemplate = analysis.generatedTemplate!;
      SmsSenderRegistry.registerCustomTemplate(generatedTemplate);

      // Verify that findTemplate now finds this new bank dynamically!
      final found = SmsSenderRegistry.findTemplate('QNB');
      expect(found, isNotNull);
      expect(found!.senderIds.contains('QNB'), isTrue);

      // Now verify standard parseMessage parses subsequent messages from this new bank!
      const subsequentSms = 'تم خصم مبلغ 200.00 ر.ق من حسابك. الرصيد المتاح 8300.00 ر.ق.';
      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'QNB',
        body: subsequentSms,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'expense');
      expect(parsed.amount, 200.0);
      expect(parsed.balance, 8300.0);
      expect(parsed.isBalanceOnly, isFalse);

      // Cleanup
      SmsSenderRegistry.clearCustomTemplates();
    });

    test('8. WalletSmsTemplate JSON Serialization and Deserialization', () {
      final template = WalletSmsTemplate.fromStrings(
        walletType: 'revolut',
        walletNameAr: 'ريفولوت',
        senderIds: ['Revolut', 'revolut'],
        incomePatterns: [r'received\s*([0-9.]+)'],
        expensePatterns: [r'spent\s*([0-9.]+)'],
        balancePatterns: [r'balance\s*([0-9.]+)'],
      );

      final json = template.toJson();
      expect(json['walletType'], 'revolut');
      expect(json['walletNameAr'], 'ريفولوت');

      final reconstructed = WalletSmsTemplate.fromJson(json);
      expect(reconstructed.walletType, 'revolut');
      expect(reconstructed.walletNameAr, 'ريفولوت');
      expect(reconstructed.senderIds, ['Revolut', 'revolut']);
      expect(reconstructed.incomePatterns.length, 1);
      expect(reconstructed.expensePatterns.length, 1);
      expect(reconstructed.balancePatterns.length, 1);
    });

    test('9. Universal Smart Wallet Matching (SmsService.findMatchingWallet)', () {
      final wallets = [
        Wallet(
          id: 'w_1',
          name: 'حساب مصرف الراجحي',
          type: 'other',
          colorValue: 0xFF1E88E5,
          iconCodePoint: 0xe040,
          openingBalance: 1000.0,
          currencyCode: 'SAR',
          createdAt: testDate,
        ),
        Wallet(
          id: 'w_2',
          name: 'المحفظة الرئيسية',
          type: 'jeeb',
          colorValue: 0xFF43A047,
          iconCodePoint: 0xe040,
          openingBalance: 500.0,
          isFavorite: true,
          currencyCode: 'YER',
          createdAt: testDate,
        ),
      ];

      final rajhiTemplate = WalletSmsTemplate.fromStrings(
        walletType: 'alrajhi',
        walletNameAr: 'مصرف الراجحي',
        senderIds: ['ALRAJHI'],
        incomePatterns: [],
        expensePatterns: [],
        balancePatterns: [],
      );

      // Match by wallet name containing bank name from template
      final matchedRajhi = SmsService.findMatchingWallet(
        userWallets: wallets,
        walletType: 'alrajhi',
        template: rajhiTemplate,
      );
      expect(matchedRajhi, isNotNull);
      expect(matchedRajhi!.id, 'w_1');

      // Match by wallet type
      final matchedJeeb = SmsService.findMatchingWallet(
        userWallets: wallets,
        walletType: 'jeeb',
      );
      expect(matchedJeeb, isNotNull);
      expect(matchedJeeb!.id, 'w_2');

      // Unknown type falls back to favorite wallet
      final matchedUnknown = SmsService.findMatchingWallet(
        userWallets: wallets,
        walletType: 'unknown_bank_123',
      );
      expect(matchedUnknown, isNotNull);
      expect(matchedUnknown!.id, 'w_2'); // isFavorite = true
    });

    test('Kuraimi Purchase SMS parses correctly as expense and reduces balance offline', () {
      const kuraimiPurchaseSms = 'تم خصم مبلغ YER 100.00 مقابل مشترياتك من 1588993 المرجع: 54177667';
      final parsed = SmsSenderRegistry.parseMessage(
        sender: 'Kuraimi',
        body: kuraimiPurchaseSms,
        date: testDate,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'expense');
      expect(parsed.amount, 100.0);
      expect(parsed.category, 'بقالة');
      expect(parsed.referenceNumber, '54177667');
      expect(parsed.balance, isNull); // Purchase SMS doesn't include remaining balance
    });
  });
}
