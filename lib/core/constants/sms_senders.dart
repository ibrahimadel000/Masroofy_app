import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/utils/smart_sms_parser.dart';

class ParsedSmsData {
  final String walletType;
  final String type; // 'income' | 'expense' | 'adjustment'
  final double amount;
  final double? balance;
  final bool isBalanceOnly;
  final String category;
  final DateTime date;
  final String rawSender;
  final String rawBody;
  final String smsKey;
  final String? referenceNumber;

  const ParsedSmsData({
    required this.walletType,
    required this.type,
    required this.amount,
    this.balance,
    this.isBalanceOnly = false,
    required this.category,
    required this.date,
    required this.rawSender,
    required this.rawBody,
    required this.smsKey,
    this.referenceNumber,
  });
}

class WalletSmsTemplate {
  final String walletType;
  final String walletNameAr;
  final List<String> senderIds;
  final List<RegExp> incomePatterns;
  final List<RegExp> expensePatterns;
  final List<RegExp> balancePatterns;
  final List<String>? incomePatternStrings;
  final List<String>? expensePatternStrings;
  final List<String>? balancePatternStrings;

  const WalletSmsTemplate({
    required this.walletType,
    required this.walletNameAr,
    required this.senderIds,
    required this.incomePatterns,
    required this.expensePatterns,
    required this.balancePatterns,
    this.incomePatternStrings,
    this.expensePatternStrings,
    this.balancePatternStrings,
  });

  /// Factory constructor to build a template from raw regex strings (e.g. from JSON / DB / User Input)
  factory WalletSmsTemplate.fromStrings({
    required String walletType,
    required String walletNameAr,
    required List<String> senderIds,
    required List<String> incomePatterns,
    required List<String> expensePatterns,
    required List<String> balancePatterns,
  }) {
    return WalletSmsTemplate(
      walletType: walletType,
      walletNameAr: walletNameAr,
      senderIds: senderIds,
      incomePatterns: incomePatterns.map((p) => RegExp(p, caseSensitive: false, dotAll: true)).toList(),
      expensePatterns: expensePatterns.map((p) => RegExp(p, caseSensitive: false, dotAll: true)).toList(),
      balancePatterns: balancePatterns.map((p) => RegExp(p, caseSensitive: false)).toList(),
      incomePatternStrings: incomePatterns,
      expensePatternStrings: expensePatterns,
      balancePatternStrings: balancePatterns,
    );
  }

  /// Serialize to JSON Map for saving to Hive or SharedPreferences or Cloud
  Map<String, dynamic> toJson() {
    return {
      'walletType': walletType,
      'walletNameAr': walletNameAr,
      'senderIds': senderIds,
      'incomePatterns': incomePatternStrings ?? incomePatterns.map((r) => r.pattern).toList(),
      'expensePatterns': expensePatternStrings ?? expensePatterns.map((r) => r.pattern).toList(),
      'balancePatterns': balancePatternStrings ?? balancePatterns.map((r) => r.pattern).toList(),
    };
  }

  /// Deserialize from JSON Map
  factory WalletSmsTemplate.fromJson(Map<String, dynamic> json) {
    return WalletSmsTemplate.fromStrings(
      walletType: json['walletType'] as String? ?? 'custom',
      walletNameAr: json['walletNameAr'] as String? ?? 'محفظة مخصصة',
      senderIds: List<String>.from(json['senderIds'] ?? []),
      incomePatterns: List<String>.from(json['incomePatterns'] ?? []),
      expensePatterns: List<String>.from(json['expensePatterns'] ?? []),
      balancePatterns: List<String>.from(json['balancePatterns'] ?? []),
    );
  }
}

class SmsSenderRegistry {
  /// Dynamic user-registered or cloud-synced templates
  static final List<WalletSmsTemplate> _customTemplates = [];
  static const String _customTemplatesKey = 'mizaan_custom_sms_templates_v1';

  /// Register a single custom template (e.g. user added their own bank)
  static void registerCustomTemplate(WalletSmsTemplate template, {bool persist = false}) {
    _customTemplates.removeWhere((t) => t.walletType == template.walletType);
    _customTemplates.insert(0, template);
    if (persist) {
      saveCustomTemplates();
    }
  }

  /// Register multiple custom templates (e.g. on app startup from local storage)
  static void registerCustomTemplates(List<WalletSmsTemplate> templates, {bool persist = false}) {
    for (final t in templates) {
      registerCustomTemplate(t, persist: false);
    }
    if (persist) {
      saveCustomTemplates();
    }
  }

  /// Remove a custom template by walletType
  static void removeCustomTemplate(String walletType, {bool persist = false}) {
    _customTemplates.removeWhere((t) => t.walletType == walletType);
    if (persist) {
      saveCustomTemplates();
    }
  }

  /// Clear all custom templates
  static void clearCustomTemplates({bool persist = false}) {
    _customTemplates.clear();
    if (persist) {
      saveCustomTemplates();
    }
  }

  /// Get all active templates (custom templates take priority, followed by defaults)
  static List<WalletSmsTemplate> getAllTemplates() {
    return [..._customTemplates, ...defaultTemplates];
  }

  /// Load custom templates saved in local SharedPreferences
  static Future<void> loadCustomTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_customTemplatesKey);
      if (list != null && list.isNotEmpty) {
        final parsed = list.map((raw) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          return WalletSmsTemplate.fromJson(map);
        }).toList();
        registerCustomTemplates(parsed, persist: false);
      }
    } catch (_) {}
  }

  /// Save custom templates to local SharedPreferences
  static Future<void> saveCustomTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customTemplates.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_customTemplatesKey, list);
    } catch (_) {}
  }

  static List<RegExp> get standardIncomePatterns => [
    // 1. Inward transfer where amount comes immediately after تحويل and before destination (e.g. تم تحويل 8000 ر.ي إلى محفظتك or تم تحويل مبلغ 50000 ريال إلى حسابك)
    RegExp(r'(?:تم\s*تحويل|تحويل)\s+(?:ب?مبلغ\s+|ب?قيمة\s+)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?:إلى\s*محفظتك|الى\s*محفظتك|لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|لك\b)', caseSensitive: false),

    // 2. Explicit amount with "مبلغ" or "بقيمة" following any deposit trigger (safely skips phone numbers/account numbers)
    RegExp(r'(?:[أا]ودع(?:ت)?|إيداع|ايداع|الإيداع|الايداع|تمت?\s*[إا]يداع|إيداع\s*نقدي|ايداع\s*نقدي|أضيف(?:ت)?|اضيف(?:ت)?|تمت?\s*[إا]ضاف[ةه]|[إا]ضاف[ةه]|تمت?\s*تغذي[ةه]|تغذي[ةه]|تحويل\s*وارد|حوال[ةه]\s*وارد[ةه]|حوال[ةه]\s*من|تحويل\s*من|استلام\s*(?:حوال[ةه]|تحويل|مبلغ)?|تم\s*استلام|استلمت|وصلك(?:ت)?\s*(?:تحويل|حوال[ةه]|مبلغ)?|قيد\s*(?:ل|في)?حساب(?:ك|كم)|تم\s*(?:قيد|القيد)|شحن|قبض|توريد|تم\s*توريد|دائن|إشعار\s*دائن|اشعار\s*دائن|عكس\s*قيد|لصالحك|قيد\s*لصالح(?:ك|كم)|حساب(?:ك|كم)\s*دائن)[\s\S]*?(?:ب?مبلغ|ب?قيمة)\s*[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),

    // 3. Amount followed immediately by currency and inward target/verb (e.g. 50,000.00 YER أودع or 8000 ر.ي إلى محفظتك or 50,000 ر.ي لحسابك)
    RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:إلى\s*محفظتك|الى\s*محفظتك|لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|[أا]ودع|إيداع|ايداع|أضيف|اضيف|[إا]ضاف[ةه]|استلام|تغذي[ةه]|وارد|دائن|لصالحك|تحويل\s*مشترك)', caseSensitive: false),

    // 4. Keyword followed by currency and amount (e.g. اضيف 500ر.ي or إيداع 1000 YER or تغذية 20000 ريال)
    RegExp(r'(?:أضيف|اضيف|أضيفت|اضيفت|إيداع|ايداع|تغذية|تغذيه|استلام|استلمت|دائن|عكس\s*قيد|لصالحك)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)', caseSensitive: false),

    // 5. Direct keyword followed immediately by amount (excluding 9-digit Yemeni phone numbers starting with 7)
    RegExp(r'(?:[أا]ودع(?:ت)?(?:\/[^\d\n]+|\s+[^\d\n]+)?(?:\s+(?:ل|في|إلى|الى|ب)?حساب(?:ك|كم)|\s+لك)?|إيداع|ايداع|الإيداع|الايداع|تمت?\s*[إا]يداع|أضيف(?:ت)?|اضيف(?:ت)?|تمت?\s*[إا]ضاف[ةه]|تغذي[ةه]|تم\s*استلام|استلام|لحساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|دائن|عكس\s*قيد|لصالحك)[\s:]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
  ];

  static final List<WalletSmsTemplate> defaultTemplates = [
    // 1. Kuraimi Bank (الكريمي)
    // Supports: Haseb (حاسب), POS (نقاط البيع), merchant purchases, mobile bills, transfers, ATM, deposits, salary
    WalletSmsTemplate(
      walletType: 'kuraimi',
      walletNameAr: 'الكريمي',
      senderIds: [
        'mfloos', 'M-Floos', 'Mfloos', 'ام فلوس',
        'KuraimiMB',
        'KuraimiIMB',
        'Kuraimi',
        'KURAIMI',
        'الكريمي',
        'Al-Kuraimi',
        'AlKuraimi',
        'KuraimiPay',
        'Haseb',
        'حاسب',
        'KIMB',
        'KuraimiBank',
        'بنك الكريمي',
      ],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:شراء|مشتريات|مشترياتك|حاسب|خدمة\s*حاسب|نقاط\s*البيع|نقطة\s*بيع|pos|دفع|تم\s*دفع|خصم|تم\s*خصم|قيد\s*خصم|سداد|تم\s*سداد|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\s\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b))|سحب|تم\s*سحب|حوال[ةه]\s*صادر[ةه])[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:خصم|شراء|سداد|(?:تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b))|سحب|حاسب)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:حسابك)?\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:الرصيد|رصيدك)', caseSensitive: false),
        RegExp(r'(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:الرصيد|رصيدك)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 2. Jaib Wallet (جيب - بنك التضامن)
    WalletSmsTemplate(
      walletType: 'jeeb',
      walletNameAr: 'جيب',
      senderIds: [
        'Jaib',
        'JAIB',
        'jaib',
        'Jeeb',
        'JEEB',
        'جيب',
        'Tadhamon',
        'TIB',
        'بنك التضامن',
        'التضامن',
        'TadhamonBank',
        'Tadhamon Bank',
        'TIB-SMS',
        'TIB_SMS',
        'TadhamonPay',
        'JAIB_WALLET',
        'JaibWallet',
        'JeebWallet',
        'Tadamon',
      ],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:تمت?\s*عملية\s*خصم|تم\s*خصم|خصم|تم\s*سداد|سداد|تم\s*دفع|دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\s\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b))|حوال[ةه]\s*صادر[ةه]|تم\s*شراء|شراء|مشتريات|تم\s*سحب|سحب|قيد\s*خصم)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:خصم|سداد|تحويل|شراء|سحب)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رص:\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:ر\.?ي|YER|ريال)?', caseSensitive: false),
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:حسابك)?\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:الرصيد|رصيدك)', caseSensitive: false),
      ],
    ),

    // 3. Kash Wallet (كاش - بنك اليمن والكويت)
    WalletSmsTemplate(
      walletType: 'kash',
      walletNameAr: 'كاش',
      senderIds: ['Kash', 'KASH', 'kash', 'YKB', 'كاش', 'بنك اليمن والكويت'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 4. Muhafazati (محفظتي)
    WalletSmsTemplate(
      walletType: 'muhafazati',
      walletNameAr: 'محفظتي',
      senderIds: ['Muhafazati', 'MTN', 'Spacetel', 'محفظتي', 'YOU', 'يو'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم|تم\s*سداد|سداد|شراء|مشتريات|تم\s*شراء|دفع|تم\s*دفع|سحب|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 5. Jawali (جوالي - كاك بنك / يمن موبايل)
    WalletSmsTemplate(
      walletType: 'jawali',
      walletNameAr: 'جوالي',
      senderIds: ['Jawali', 'CACBank', 'CAC_Bank', 'جوالي', 'CAC', 'كاك بنك', 'كاك', 'CAC BANK', 'السريع'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم|تم\s*سداد|سداد فاتورة|سداد|سحب|شراء|مشتريات|تم\s*شراء|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 6. OneCash (ون كاش - بنك القطيبي)
    WalletSmsTemplate(
      walletType: 'onecash',
      walletNameAr: 'ون كاش',
      senderIds: ['OneCash', 'ONECASH', 'onecash', 'ون كاش', 'القطيبي', 'AlQutaibi', 'Qutaibi', 'بنك القطيبي', 'Al-Qutaibi'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 7. Al-Amqi (العمقي للصرافة)
    WalletSmsTemplate(
      walletType: 'alamqi',
      walletNameAr: 'العمقي',
      senderIds: ['AlAmqi', 'Alamqi', 'ALAMQI', 'العمقي', 'AMQI', 'Amqi', 'شركة العمقي', 'العمقي للصرافة'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 8. Floosak (فلوسك - بنك اليمن والبحرين الشامل)
    WalletSmsTemplate(
      walletType: 'floosak',
      walletNameAr: 'فلوسك',
      senderIds: ['Floosak', 'FLOOSAK', 'floosak', 'فلوسك', 'YBR', 'بنك البحرين الشامل', 'الشامل', 'Shamil', 'shamil'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 9. PYes (بايس - بنك سبأ الإفريقي / بنك سبأ الإسلامي)
    WalletSmsTemplate(
      walletType: 'pyes',
      walletNameAr: 'بايس',
      senderIds: ['PYes', 'PYES', 'pyes', 'بايس', 'SabaBank', 'بنك سبأ', 'سبأ'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 10. Al-Busairi (البصيري للصرافة)
    WalletSmsTemplate(
      walletType: 'busairi',
      walletNameAr: 'البصيري',
      senderIds: ['Busairi', 'BUSAIRI', 'busairi', 'البصيري', 'شركة البصيري', 'AlBusairi', 'Al-Busairi'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 11. WeePay (وي باي - بنك اليمن الدولي)
    WalletSmsTemplate(
      walletType: 'weepay',
      walletNameAr: 'وي باي',
      senderIds: ['WeePay', 'WEEPAY', 'weepay', 'وي باي', 'IBY', 'بنك اليمن الدولي', 'اليمن الدولي'],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b)))[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 12. Universal Bank / Financial Template
    // Matches any unlisted bank, exchange agency, or numeric shortcode sending financial transactions
    WalletSmsTemplate(
      walletType: 'universal_bank',
      walletNameAr: 'محفظة بنكية',
      senderIds: [
        'Bank', 'SMS', 'Alert', 'Finance', 'Info', '2020', '1001', 'بنك', 'صرافة', 'حوالات',
      ],
      incomePatterns: standardIncomePatterns,
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|قيد\s*خصم|سداد|تم\s*سداد|دفع|تم\s*دفع|(?:تم\s*تحويل|تحويل)(?!\s*وارد)(?![\\s\\S]*?(?:لحساب(?:ك|كم)|إلى\s*حساب(?:ك|كم)|الى\s*حساب(?:ك|كم)|في\s*حساب(?:ك|كم)|إلى\s*محفظتك|الى\s*محفظتك|لك\b))|حوال[ةه]\s*صادر[ةه]|شراء|مشتريات|تم\s*شراء|سحب|تم\s*سحب)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?!(?:7[01378]\d{7}))([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:خصم|سداد|تحويل|شراء|سحب)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),
  ];

  /// Normalize Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) to standard ASCII digits (0-9),
  /// and normalize Arabic decimal separator (٫ U+066B) and Arabic thousands separator (٬ U+066C)
  static String normalizeDigits(String input) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const ascii = '0123456789';
    var res = input;
    for (int i = 0; i < arabicIndic.length; i++) {
      res = res.replaceAll(arabicIndic[i], ascii[i]);
    }
    res = res.replaceAll('٫', '.').replaceAll('٬', ',');
    return res;
  }

  /// Clean numeric amount string (removes commas)
  static double? parseAmount(String raw) {
    try {
      final cleaned = raw.replaceAll(',', '').trim();
      return double.tryParse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// Find matching template for a given SMS sender address and optional message body
  static WalletSmsTemplate? findTemplate(
    String sender, [
    Map<String, String>? customMappings,
    String? body,
  ]) {
    final cleanSender = sender.trim().toLowerCase();
    final all = getAllTemplates();

    // 1. Check custom mappings first (e.g. user mapped a number/contact to wallet type)
    if (customMappings != null) {
      for (final entry in customMappings.entries) {
        if (cleanSender == entry.key.trim().toLowerCase()) {
          return all.firstWhere(
            (t) => t.walletType == entry.value,
            orElse: () => all.first,
          );
        }
      }
    }

    // 2. Check senderIds across all templates (excluding universal_bank in first pass)
    for (final template in all) {
      if (template.walletType == 'universal_bank') continue;
      for (final id in template.senderIds) {
        final cleanId = id.toLowerCase();
        if (cleanSender == cleanId ||
            cleanSender.contains(cleanId) ||
            cleanId.contains(cleanSender)) {
          return template;
        }
      }
    }

    // 3. Inspect body content if sender alone did not match (e.g. sender is a numeric shortcode like 2020)
    if (body != null && body.trim().isNotEmpty) {
      final cleanBody = body.toLowerCase();

      // Check specific bank keywords inside body
      if (cleanBody.contains('جيب') ||
          cleanBody.contains('تضامن') ||
          cleanBody.contains('jaib') ||
          cleanBody.contains('jeeb') ||
          cleanBody.contains('tadhamon')) {
        return all.firstWhere((t) => t.walletType == 'jeeb', orElse: () => all.first);
      }
      if (cleanBody.contains('كريمي') ||
          cleanBody.contains('kuraimi') ||
          cleanBody.contains('حاسب') ||
          cleanBody.contains('kimb')) {
        return all.firstWhere((t) => t.walletType == 'kuraimi', orElse: () => all.first);
      }
      if (cleanBody.contains('ون كاش') ||
          cleanBody.contains('onecash') ||
          cleanBody.contains('القطيبي') ||
          cleanBody.contains('قطيبي')) {
        return all.firstWhere((t) => t.walletType == 'onecash', orElse: () => all.first);
      }
      if (cleanBody.contains('كاش') ||
          cleanBody.contains('kash') ||
          cleanBody.contains('اليمن والكويت')) {
        return all.firstWhere((t) => t.walletType == 'kash', orElse: () => all.first);
      }
      if (cleanBody.contains('جوالي') ||
          cleanBody.contains('jawali') ||
          cleanBody.contains('كاك') ||
          cleanBody.contains('cac')) {
        return all.firstWhere((t) => t.walletType == 'jawali', orElse: () => all.first);
      }
      if (cleanBody.contains('فلوسك') ||
          cleanBody.contains('floosak') ||
          cleanBody.contains('شامل') ||
          cleanBody.contains('ybr')) {
        return all.firstWhere((t) => t.walletType == 'floosak', orElse: () => all.first);
      }
      if (cleanBody.contains('العمقي') ||
          cleanBody.contains('عمقي') ||
          cleanBody.contains('alamqi')) {
        return all.firstWhere((t) => t.walletType == 'alamqi', orElse: () => all.first);
      }
      if (cleanBody.contains('محفظتي') ||
          cleanBody.contains('mahfathati') ||
          cleanBody.contains('you') ||
          cleanBody.contains('يو')) {
        return all.firstWhere((t) => t.walletType == 'muhafazati', orElse: () => all.first);
      }
      if (cleanBody.contains('بايس') ||
          cleanBody.contains('pyes') ||
          cleanBody.contains('سبأ') ||
          cleanBody.contains('saba')) {
        return all.firstWhere((t) => t.walletType == 'pyes', orElse: () => all.first);
      }
      if (cleanBody.contains('بصيري') ||
          cleanBody.contains('busairi') ||
          cleanBody.contains('البصيري')) {
        return all.firstWhere((t) => t.walletType == 'busairi', orElse: () => all.first);
      }
      if (cleanBody.contains('وي باي') ||
          cleanBody.contains('weepay') ||
          cleanBody.contains('اليمن الدولي') ||
          cleanBody.contains('iby')) {
        return all.firstWhere((t) => t.walletType == 'weepay', orElse: () => all.first);
      }

      // 4. Reject non-banking promotional campaigns, discount offers, and telecom advertisements
      const promoIndicators = [
        'عرض خاص', 'عروض', 'خصومات', 'اشترك', 'باقات', 'اربح', 'جوائز', 'مبروك',
        'مجانا', 'وفر', 'كود خصم', 'كوبون', 'باقة',
      ];
      final isPromo = promoIndicators.any((kw) => cleanBody.contains(kw));
      final hasBankAnchor = cleanBody.contains('رصيد') ||
          cleanBody.contains('حسابك') ||
          cleanBody.contains('محفظت') ||
          cleanBody.contains('مرجع') ||
          cleanBody.contains('ref') ||
          cleanBody.contains('تغذية') ||
          cleanBody.contains('تغذيه') ||
          cleanBody.contains('إيداع') ||
          cleanBody.contains('ايداع') ||
          cleanBody.contains('أودع') ||
          cleanBody.contains('اودع') ||
          cleanBody.contains('أضيف') ||
          cleanBody.contains('اضيف') ||
          cleanBody.contains('إضافة') ||
          cleanBody.contains('اضافة') ||
          cleanBody.contains('إضافه') ||
          cleanBody.contains('اضافه') ||
          cleanBody.contains('حوالة') ||
          cleanBody.contains('حواله') ||
          cleanBody.contains('تحويل');

      if (isPromo && !hasBankAnchor) {
        return null;
      }

      // If body contains any financial transaction keywords, fall back to universal bank template
      const financialTriggers = [
        'إيداع', 'ايداع', 'الإيداع', 'الايداع', 'أودع', 'اودع', 'أضيف', 'اضيف', 'إضافة', 'اضافة', 'إضافه', 'اضافه',
        'استلام', 'تغذية', 'تغذيه', 'خصم', 'شراء', 'مشتريات', 'سداد', 'تحويل', 'دفع', 'سحب', 'حوالة', 'حواله', 'قيد',
        'رصيدك', 'رصيد حسابك', 'الرصيد الحالي', 'رص:', 'شحن', 'قبض', 'توريد',
      ];
      final isFinancial = financialTriggers.any((kw) => cleanBody.contains(kw));
      if (isFinancial) {
        final universal = all.firstWhere(
          (t) => t.walletType == 'universal_bank',
          orElse: () => all.first,
        );
        return universal;
      }
    }

    return null;
  }

  /// Guess transaction category based on message content
  static String guessCategory(String body) {
    final text = body.toLowerCase();
    if (text.contains('مطعم') ||
        text.contains('كافيه') ||
        text.contains('وجبة') ||
        text.contains('شاورما') ||
        text.contains('كافتيريا') ||
        text.contains('برجر')) {
      return 'أكل';
    }
    if (text.contains('سوبرماركت') ||
        text.contains('بقالة') ||
        text.contains('هايبر') ||
        text.contains('ماركت') ||
        text.contains('تموينات') ||
        text.contains('مشتريات') ||
        text.contains('حاسب') ||
        text.contains('شراء') ||
        text.contains('متجر') ||
        text.contains('مركز') ||
        text.contains('سوق') ||
        text.contains('مول') ||
        text.contains('نقطة بيع') ||
        text.contains('pos')) {
      return 'بقالة';
    }
    if (text.contains('سداد') ||
        text.contains('جوال') ||
        text.contains('يمن موبايل') ||
        text.contains('سبأفون') ||
        text.contains('يو') ||
        text.contains('فاتورة') ||
        text.contains('فواتير') ||
        text.contains('كهرباء') ||
        text.contains('مياه') ||
        text.contains('نت') ||
        text.contains('انترنت')) {
      return 'فواتير';
    }
    if (text.contains('تاكسي') ||
        text.contains('باص') ||
        text.contains('بنزين') ||
        text.contains('مشوار') ||
        text.contains('مواصلات') ||
        text.contains('بترول')) {
      return 'مواصلات';
    }
    if (text.contains('تحويل') ||
        text.contains('أودع') ||
        text.contains('اودع') ||
        text.contains('إيداع') ||
        text.contains('ايداع') ||
        text.contains('حوالة') ||
        text.contains('حواله') ||
        text.contains('لحسابك') ||
        text.contains('مشترك')) {
      return 'تحويل';
    }
    if (text.contains('راتب') || text.contains('مرتب')) {
      return 'راتب';
    }
    return 'أخرى';
  }

  /// Extract bank reference number from SMS body if present
  static String? extractReferenceNumber(String body) {
    final patterns = [
      RegExp(r'(?:المرجع|مرجع|ref(?:erence)?|ref\s*#|trx[:\s]|txn[:\s]|trans(?:\s*id)?[:\s]|رقم\s*العملية|رقم\s*المرجع|رقم\s*الحوالة|رقم\s*[إا]شعار|رقم\s*ال[إا]شعار|ال[إا]شعار|[إا]شعار\s*رقم|رقم\s*السند|رقم\s*الحركة|عملية\s*رقم|حركة\s*رقم|رقم\s*القيد|كود\s*الحركة)[\s:#]*([0-9a-zA-Z]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty && val.length >= 4) {
          return val;
        }
      }
    }
    return null;
  }

  /// Fast, deterministic 31-bit polynomial hash for string content across all isolates
  static String deterministicHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = (((hash << 5) + hash) + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// Generate unique deduplication key for an SMS
  static String generateSmsKey(String sender, DateTime date, String body) {
    final ref = extractReferenceNumber(body);
    final cleanSender = sender.trim().toLowerCase();
    if (ref != null && ref.isNotEmpty) {
      return '${cleanSender}_ref_$ref';
    }
    // Stable day-bucketed normalized content key (resistant to second/minute differences between live listener & inbox)
    final normalized = normalizeDigits(body)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final bodyHash = deterministicHash(normalized);
    return '${cleanSender}_${date.year}_${date.month}_${date.day}_$bodyHash';
  }

  /// Parse a single SMS message into a ParsedSmsData object (or null if not matching)
  static ParsedSmsData? parseMessage({
    required String sender,
    required String body,
    required DateTime date,
    Map<String, String>? customMappings,
  }) {
    final normalized = normalizeDigits(body);

    const promoIndicators = [
      'عرض خاص', 'عروض', 'خصومات', 'اشترك', 'باقات', 'اربح', 'جوائز', 'مبروك',
      'مجانا', 'وفر', 'كود خصم', 'كوبون', 'باقة',
    ];
    final isPromo = promoIndicators.any((kw) => normalized.contains(kw));
    final hasBankAnchor = normalized.contains('رصيد') ||
        normalized.contains('حسابك') ||
        normalized.contains('محفظت') ||
        normalized.contains('مرجع') ||
        normalized.contains('ref') ||
        normalized.contains('تغذية') ||
        normalized.contains('تغذيه') ||
        normalized.contains('إيداع') ||
        normalized.contains('ايداع') ||
        normalized.contains('أودع') ||
        normalized.contains('اودع') ||
        normalized.contains('أضيف') ||
        normalized.contains('اضيف') ||
        normalized.contains('إضافة') ||
        normalized.contains('اضافة') ||
        normalized.contains('إضافه') ||
        normalized.contains('اضافه') ||
        normalized.contains('حوالة') ||
        normalized.contains('حواله') ||
        normalized.contains('تحويل');

    if (isPromo && !hasBankAnchor) {
      return null;
    }

    final template = findTemplate(sender, customMappings, body);
    if (template == null) return null;

    // Pass 1: Extract balance and isolate its match range
    double? balance;
    String textWithoutBalance = normalized;

    for (final pattern in template.balancePatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        for (int g = 1; g <= match.groupCount; g++) {
          final rawBal = match.group(g);
          if (rawBal != null) {
            final parsedBal = parseAmount(rawBal);
            if (parsedBal != null) {
              balance = parsedBal;
              // Mask the entire balance clause so Pass 2 cannot accidentally capture it
              textWithoutBalance = normalized.replaceRange(match.start, match.end, ' ');
              break;
            }
          }
        }
      }
      if (balance != null) break;
    }

    double? amount;
    String? type;

    // Pass 2: Extract operation amount from text excluding the balance clause
    for (final pattern in template.incomePatterns) {
      final match = pattern.firstMatch(textWithoutBalance);
      if (match != null && match.groupCount >= 1) {
        final rawAmount = match.group(1);
        if (rawAmount != null) {
          final parsed = parseAmount(rawAmount);
          if (parsed != null && parsed > 0) {
            amount = parsed;
            type = 'income';
            break;
          }
        }
      }
    }

    // Check expense if not income
    if (type == null) {
      for (final pattern in template.expensePatterns) {
        final match = pattern.firstMatch(textWithoutBalance);
        if (match != null && match.groupCount >= 1) {
          final rawAmount = match.group(1);
          if (rawAmount != null) {
            final parsed = parseAmount(rawAmount);
            if (parsed != null && parsed > 0) {
              amount = parsed;
              type = 'expense';
              break;
            }
          }
        }
      }
    }

    // Pass 2.5: Resilient Fallback Parser for Bank SMS with non-standard formatting
    if (amount == null || type == null) {
      final isInc = textWithoutBalance.contains('أودع') ||
          textWithoutBalance.contains('اودع') ||
          textWithoutBalance.contains('أودعت') ||
          textWithoutBalance.contains('اودعت') ||
          textWithoutBalance.contains('إيداع') ||
          textWithoutBalance.contains('ايداع') ||
          textWithoutBalance.contains('الإيداع') ||
          textWithoutBalance.contains('الايداع') ||
          textWithoutBalance.contains('أضيف') ||
          textWithoutBalance.contains('اضيف') ||
          textWithoutBalance.contains('أضيفت') ||
          textWithoutBalance.contains('اضيفت') ||
          textWithoutBalance.contains('إضافة') ||
          textWithoutBalance.contains('اضافة') ||
          textWithoutBalance.contains('إضافه') ||
          textWithoutBalance.contains('اضافه') ||
          textWithoutBalance.contains('استلام') ||
          textWithoutBalance.contains('تغذية') ||
          textWithoutBalance.contains('تغذيه') ||
          textWithoutBalance.contains('قيد لحساب') ||
          textWithoutBalance.contains('قيد في حساب') ||
          textWithoutBalance.contains('تم قيد') ||
          textWithoutBalance.contains('تم القيد') ||
          textWithoutBalance.contains('تحويل وارد') ||
          textWithoutBalance.contains('حوالة واردة') ||
          textWithoutBalance.contains('حواله وارده') ||
          textWithoutBalance.contains('حوالة من') ||
          textWithoutBalance.contains('حواله من') ||
          textWithoutBalance.contains('تحويل من') ||
          textWithoutBalance.contains('تحويل إلى') ||
          textWithoutBalance.contains('تحويل الى') ||
          textWithoutBalance.contains('تحويل لك') ||
          textWithoutBalance.contains('تحويل لحساب') ||
          textWithoutBalance.contains('وصلك تحويل') ||
          textWithoutBalance.contains('وصلتك حوالة') ||
          textWithoutBalance.contains('وصلتك حواله') ||
          textWithoutBalance.contains('وصلك مبلغ') ||
          textWithoutBalance.contains('شحن') ||
          textWithoutBalance.contains('قبض') ||
          textWithoutBalance.contains('توريد') ||
          textWithoutBalance.contains('لحسابك') ||
          textWithoutBalance.contains('لحسابكم') ||
          textWithoutBalance.contains('في حسابك') ||
          textWithoutBalance.contains('في حسابكم') ||
          textWithoutBalance.contains('إلى محفظتك') ||
          textWithoutBalance.contains('الى محفظتك') ||
          textWithoutBalance.contains('دائن') ||
          textWithoutBalance.contains('إشعار دائن') ||
          textWithoutBalance.contains('اشعار دائن') ||
          textWithoutBalance.contains('عكس قيد') ||
          textWithoutBalance.contains('لصالحك') ||
          textWithoutBalance.contains('قيد لصالح') ||
          textWithoutBalance.contains('حسابكم دائن') ||
          textWithoutBalance.contains('حسابك دائن') ||
          textWithoutBalance.contains('استلمت') ||
          textWithoutBalance.contains('تم استلام') ||
          textWithoutBalance.contains('تم توريد') ||
          textWithoutBalance.contains('إلى حسابك') ||
          textWithoutBalance.contains('الى حسابك');

      final hasInwardTarget = textWithoutBalance.contains('لحسابك') ||
          textWithoutBalance.contains('لحسابكم') ||
          textWithoutBalance.contains('إلى حسابك') ||
          textWithoutBalance.contains('الى حسابك') ||
          textWithoutBalance.contains('في حسابك') ||
          textWithoutBalance.contains('في حسابكم') ||
          textWithoutBalance.contains('إلى محفظتك') ||
          textWithoutBalance.contains('الى محفظتك') ||
          textWithoutBalance.contains('لك');

      final isExp = textWithoutBalance.contains('خصم') ||
          textWithoutBalance.contains('شراء') ||
          textWithoutBalance.contains('مشتريات') ||
          textWithoutBalance.contains('سداد') ||
          textWithoutBalance.contains('دفع') ||
          textWithoutBalance.contains('حاسب') ||
          textWithoutBalance.contains('سحب') ||
          (textWithoutBalance.contains('تحويل') && !hasInwardTarget) ||
          textWithoutBalance.contains('حوالة صادرة') ||
          textWithoutBalance.contains('حواله صادره') ||
          textWithoutBalance.contains('قيد خصم');

      if (isInc || isExp) {
        final fallbackPatterns = [
          // 1. Inward transfer pattern (amount before destination): تم تحويل 8000 ر.ي إلى محفظتك...
          RegExp(r'(?:تم\s+)?(?:تحويل|توريد|إيداع|ايداع)\s+(?:مبلغ\s+)?([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*(?:إلى|الى|في|لحساب)', caseSensitive: false),
          // 2. Explicit amount keyword
          RegExp(r'(?:ب?مبلغ|ب?قيمة)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?', caseSensitive: false),
          // 3. Currency adjacent
          RegExp(r'(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
          RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)', caseSensitive: false),
          // 4. Any number excluding 9-digit Yemeni phone numbers
          RegExp(r'(?<!\d)(?!(?:7[01378]\d{7}))([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]+)?|[0-9]+(?:\.[0-9]+)?)(?!\d)', caseSensitive: false),
        ];

        for (final p in fallbackPatterns) {
          final m = p.firstMatch(textWithoutBalance);
          if (m != null && m.groupCount >= 1) {
            final raw = m.group(1);
            if (raw != null) {
              final parsedVal = parseAmount(raw);
              if (parsedVal != null && parsedVal > 0) {
                amount = parsedVal;
                type = isInc ? 'income' : (isExp ? 'expense' : 'income');
                break;
              }
            }
          }
        }
      }
    }

    // Pass 3: SmartSmsParser Universal Deep Fallback
    if (amount == null || type == null) {
      try {
        final smart = SmartSmsParser.analyzeSms(body: body, sender: sender);
        if (smart.isSuccess) {
          amount = smart.amount;
          type = smart.type;
          balance ??= smart.balance;
        }
      } catch (_) {}
    }

    final refNumber = extractReferenceNumber(body);
    final smsKey = generateSmsKey(sender, date, body);

    final hasTransactionAction = isPromo ? false : (
      normalized.contains('خصم') ||
      normalized.contains('شراء') ||
      normalized.contains('سداد') ||
      normalized.contains('سحب') ||
      normalized.contains('دفع') ||
      normalized.contains('حاسب') ||
      normalized.contains('أودع') ||
      normalized.contains('اودع') ||
      normalized.contains('إيداع') ||
      normalized.contains('ايداع') ||
      normalized.contains('أضيف') ||
      normalized.contains('اضيف') ||
      normalized.contains('إضافة') ||
      normalized.contains('اضافة') ||
      normalized.contains('إضافه') ||
      normalized.contains('اضافه') ||
      normalized.contains('تغذية') ||
      normalized.contains('تغذيه') ||
      normalized.contains('استلام') ||
      normalized.contains('تحويل') ||
      normalized.contains('حوالة') ||
      normalized.contains('حواله') ||
      normalized.contains('قيد') ||
      normalized.contains('دائن') ||
      normalized.contains('لصالحك')
    );

    // Disambiguation: Pure balance inquiry / statement notification
    if ((amount == null || amount == 0.0 || type == null || type == 'adjustment') && balance != null && !hasTransactionAction) {
      return ParsedSmsData(
        walletType: template.walletType,
        type: 'adjustment',
        amount: 0.0,
        balance: balance,
        isBalanceOnly: true,
        category: 'كشف حساب',
        date: date,
        rawSender: sender,
        rawBody: body,
        smsKey: smsKey,
        referenceNumber: refNumber,
      );
    }

    if (amount == null || type == null) {
      return null;
    }

    final category = guessCategory(body);

    return ParsedSmsData(
      walletType: template.walletType,
      type: type,
      amount: amount,
      balance: balance,
      isBalanceOnly: false,
      category: category,
      date: date,
      rawSender: sender,
      rawBody: body,
      smsKey: smsKey,
      referenceNumber: refNumber,
    );
  }
}


