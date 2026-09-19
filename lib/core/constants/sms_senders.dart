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

  static final List<WalletSmsTemplate> defaultTemplates = [
    // 1. Kuraimi Bank (الكريمي)
    // Supports: Haseb (حاسب), POS (نقاط البيع), merchant purchases, mobile bills, transfers, ATM, deposits, salary
    WalletSmsTemplate(
      walletType: 'kuraimi',
      walletNameAr: 'الكريمي',
      senderIds: [
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
      incomePatterns: [
        RegExp(r'(?:[أا]ودع[\s\S]*?لحسابك|إيداع|ايداع|تم استلام|تم إيداع|تحويل وارد|حوالة واردة|أضيف|اضيف|إضافة|اضافة|تمت إضافة|تم اضافة|تغذية|قيد لحسابك|تحويل إلى|تحويل الى|تحويل لك|وصلك تحويل)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:لحسابك|أودع|إيداع|أضيف|إضافة|استلام)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'(?:شراء|مشتريات|مشترياتك|حاسب|خدمة\s*حاسب|نقاط\s*البيع|نقطة\s*بيع|pos|دفع|تم\s*دفع|خصم|تم\s*خصم|قيد\s*خصم|سداد|تم\s*سداد|تحويل|تم\s*تحويل|سحب|تم\s*سحب|حوالة صادرة)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:خصم|شراء|سداد|تحويل|سحب|حاسب)', caseSensitive: false),
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
      incomePatterns: [
        RegExp(r'(?:[إا]ضافة|أضيف|اضيف|تمت?\s*[إا]ضافة|إيداع|ايداع|تم\s*إيداع|تم\s*ايداع|أودع|اودع|استلام|تم\s*استلام|تغذية|تمت?\s*تغذية|قيد\s*لحسابك|تم\s*قيد|تحويل\s*وارد|حوالة\s*واردة|تحويل\s*(?:إلى|الى|لك|لحسابك)|وصلك\s*تحويل)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:إلى\s*محفظتك|لحسابك|أضيف|إضافة|إيداع|استلام)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'(?:تمت?\s*عملية\s*خصم|تم\s*خصم|خصم|تم\s*سداد|سداد|تم\s*دفع|دفع|تم\s*تحويل|تحويل|حوالة\s*صادرة|تم\s*شراء|شراء|مشتريات|تم\s*سحب|سحب|قيد\s*خصم)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
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
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|إضافة|اضافة|تمت إضافة|تم اضافة|تغذية|تحويل وارد|حوالة واردة|تحويل إلى|تحويل الى|تحويل لك)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع|تحويل)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 4. Muhafazati (محفظتي)
    WalletSmsTemplate(
      walletType: 'muhafazati',
      walletNameAr: 'محفظتي',
      senderIds: ['Muhafazati', 'MTN', 'Spacetel', 'محفظتي', 'YOU', 'يو'],
      incomePatterns: [
        RegExp(r'(?:تم استلام|إيداع|ايداع|تمت إضافة|تم اضافة|أضيف|اضيف|إضافة|اضافة|تغذية|تحويل وارد|حوالة واردة|تحويل لك)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم|تم\s*تحويل|تم\s*سداد|سداد|شراء|مشتريات|تم\s*شراء|دفع|تم\s*دفع|سحب)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 5. Jawali (جوالي - كاك بنك / يمن موبايل)
    WalletSmsTemplate(
      walletType: 'jawali',
      walletNameAr: 'جوالي',
      senderIds: ['Jawali', 'YemenMobile', 'CACBank', 'CAC_Bank', 'جوالي', 'CAC', 'كاك بنك', 'كاك', 'CAC BANK'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تحويل لحسابك|تحويل وارد|حوالة واردة|أودع|اودع|اضيف|أضيف|إضافة|اضافة|تمت إضافة|تغذية)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم|تم\s*سداد|سداد فاتورة|سداد|تم\s*تحويل|سحب|شراء|مشتريات|تم\s*شراء|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 6. OneCash (ون كاش - بنك القطيبي)
    WalletSmsTemplate(
      walletType: 'onecash',
      walletNameAr: 'ون كاش',
      senderIds: ['OneCash', 'ONECASH', 'onecash', 'ون كاش', 'القطيبي', 'AlQutaibi', 'Qutaibi', 'بنك القطيبي', 'Al-Qutaibi'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|إضافة|اضافة|تمت إضافة|تغذية|تحويل وارد|حوالة واردة|تحويل إلى|تحويل الى|تحويل لك)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
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
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|إضافة|اضافة|تمت إضافة|تغذية|تحويل وارد|حوالة واردة|تحويل إلى|تحويل الى|تحويل لك)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
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
      senderIds: ['Floosak', 'FLOOSAK', 'floosak', 'فلوسك', 'YBR', 'بنك البحرين الشامل', 'الشامل', 'Shamil'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|إضافة|اضافة|تمت إضافة|تغذية|تحويل وارد|حوالة واردة|تحويل إلى|تحويل الى|تحويل لك)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),

    // 9. Universal Bank / Financial Template
    // Matches any unlisted bank, exchange agency, or numeric shortcode sending financial transactions
    WalletSmsTemplate(
      walletType: 'universal_bank',
      walletNameAr: 'محفظة بنكية',
      senderIds: [
        'Bank', 'SMS', 'Alert', 'Finance', 'Info', '2020', '1001', 'بنك', 'صرافة', 'حوالات',
      ],
      incomePatterns: [
        RegExp(r'(?:[إا]ضافة|أضيف|اضيف|تمت?\s*[إا]ضافة|إيداع|ايداع|تم\s*إيداع|تم\s*ايداع|أودع|اودع|استلام|تم\s*استلام|تغذية|تمت?\s*تغذية|قيد\s*لحسابك|تم\s*قيد|تحويل\s*وارد|حوالة\s*واردة|تحويل\s*(?:إلى|الى|لك|لحسابك)|وصلك\s*تحويل)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*(?:إلى\s*حسابك|لحسابك|أضيف|إضافة|إيداع|استلام)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|قيد\s*خصم|سداد|تم\s*سداد|دفع|تم\s*دفع|تحويل|تم\s*تحويل|حوالة\s*صادرة|شراء|مشتريات|تم\s*شراء|سحب|تم\s*سحب)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
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
          cleanBody.contains('إيداع') ||
          cleanBody.contains('ايداع');

      if (isPromo && !hasBankAnchor) {
        return null;
      }

      // If body contains any financial transaction keywords, fall back to universal bank template
      const financialTriggers = [
        'إيداع', 'ايداع', 'أودع', 'اودع', 'أضيف', 'اضيف', 'إضافة', 'اضافة', 'استلام', 'تغذية',
        'خصم', 'شراء', 'مشتريات', 'سداد', 'تحويل', 'دفع', 'سحب', 'حوالة', 'قيد',
        'رصيدك', 'رصيد حسابك', 'الرصيد الحالي',
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
        normalized.contains('إيداع') ||
        normalized.contains('ايداع');

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
          textWithoutBalance.contains('إيداع') ||
          textWithoutBalance.contains('ايداع') ||
          textWithoutBalance.contains('أضيف') ||
          textWithoutBalance.contains('اضيف') ||
          textWithoutBalance.contains('إضافة') ||
          textWithoutBalance.contains('اضافة') ||
          textWithoutBalance.contains('استلام') ||
          textWithoutBalance.contains('تغذية') ||
          textWithoutBalance.contains('قيد لحسابك') ||
          textWithoutBalance.contains('تحويل وارد') ||
          textWithoutBalance.contains('حوالة واردة') ||
          textWithoutBalance.contains('تحويل إلى') ||
          textWithoutBalance.contains('تحويل الى') ||
          textWithoutBalance.contains('تحويل لك') ||
          textWithoutBalance.contains('وصلك تحويل');

      final isExp = textWithoutBalance.contains('خصم') ||
          textWithoutBalance.contains('شراء') ||
          textWithoutBalance.contains('مشتريات') ||
          textWithoutBalance.contains('سداد') ||
          textWithoutBalance.contains('دفع') ||
          textWithoutBalance.contains('حاسب') ||
          textWithoutBalance.contains('سحب') ||
          textWithoutBalance.contains('تحويل') ||
          textWithoutBalance.contains('حوالة صادرة') ||
          textWithoutBalance.contains('قيد خصم');

      if (isInc || isExp) {
        final fallbackPatterns = [
          RegExp(r'(?:ب?مبلغ|ب?قيمة)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?', caseSensitive: false),
          RegExp(r'(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
          RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)', caseSensitive: false),
        ];

        for (final p in fallbackPatterns) {
          final m = p.firstMatch(textWithoutBalance);
          if (m != null && m.groupCount >= 1) {
            final raw = m.group(1);
            if (raw != null) {
              final parsedVal = parseAmount(raw);
              if (parsedVal != null && parsedVal > 0) {
                amount = parsedVal;
                type = isInc ? 'income' : 'expense';
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

    // Disambiguation: Pure balance inquiry / statement notification
    if ((amount == null || amount == 0.0 || type == null || type == 'adjustment') && balance != null) {
      return ParsedSmsData(
        walletType: template.walletType,
        type: 'adjustment',
        amount: 0.0,
        balance: balance,
        isBalanceOnly: true,
        category: 'أخرى',
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
