import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
      ],
      incomePatterns: [
        RegExp(r'[أا]ودع[\s\S]*?لحسابك\s*(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false, dotAll: true),
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|تحويل وارد|حوالة واردة|أضيف|اضيف)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        // 1. Purchase / Haseb / POS with explicit amount prefix (highest precision)
        RegExp(r'(?:شراء|مشتريات|مشترياتك|حاسب|خدمة\s*حاسب|نقاط\s*البيع|نقطة\s*بيع|pos|دفع)[\s\S]*?(?:ب?مبلغ|ب?قيمة)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
        // 2. Deduction with explicit amount or merchant
        RegExp(r'(?:تم\s*خصم|خصم|قيد\s*خصم)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
        // 3. Purchase / Shopping direct
        RegExp(r'(?:تمت?\s*عملية\s*شراء|تم\s*شراء|شراء|مشتريات|مشترياتك|حاسب)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
        // 4. Payment / Bill settlement / Phone recharge
        RegExp(r'(?:تم\s*سداد|سداد|تم\s*دفع|دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
        // 5. Transfer out
        RegExp(r'(?:تم\s*تحويل|تحويل)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
        // 6. Cash withdrawal
        RegExp(r'(?:تم\s*سحب|سحب)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
      ],
      balancePatterns: [
        // 1. Prefix with optional currency/words: "رصيدك هو 945.30", "رصيدك YER 4045.3", "رصيدك: 945.30", "رصيدك 4,200.00 YER", "رصيدك1,445.30YER"
        RegExp(r'رصيدك\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        // 2. Suffix with YER/currency attached: "945.30YERرصيدك", "5,045.30YERرصيدك", "1,445.30YERرصيدك"
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
        // 3. Currency before number with suffix: "YER 2,545.30 رصيدك"
        RegExp(r'(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*([0-9,]+(?:\.[0-9]+)?)\s*رصيدك', caseSensitive: false),
        // 4. Combined: "51,245.30YERرصيدك"
        RegExp(r'(?:YER\s*)?([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|ر\.?ي|ريال)+\s*رصيدك', caseSensitive: false),
        // 5. Explicit account statement inquiry
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 2. Jaib Wallet (جيب - بنك التضامن)
    WalletSmsTemplate(
      walletType: 'jeeb',
      walletNameAr: 'جيب',
      senderIds: ['Jaib', 'JAIB', 'jaib', 'Jeeb', 'JEEB', 'جيب', 'Tadhamon', 'TIB'],
      incomePatterns: [
        RegExp(r'[أا]ضيف[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?([0-9,]+(?:\.[0-9]+)?)\s*(?:ر\.?ي|YER|SAR|USD|\$)?', caseSensitive: false),
        RegExp(r'(?:إيداع|ايداع|تم استلام|تحويل وارد|حوالة واردة)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?([0-9,]+(?:\.[0-9]+)?)\s*(?:ر\.?ي|YER|SAR|USD|\$)?', caseSensitive: false),
        RegExp(r'(?:تم\s*سداد|سداد|تم\s*تحويل|تحويل|تم\s*شراء|شراء|مشتريات|تم\s*دفع|دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رص:\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:ر\.?ي|YER)?', caseSensitive: false),
        RegExp(r'رصيدك[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 3. Kash Wallet (كاش - بنك اليمن والكويت)
    WalletSmsTemplate(
      walletType: 'kash',
      walletNameAr: 'كاش',
      senderIds: ['Kash', 'KASH', 'kash', 'YKB', 'كاش'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|تحويل وارد|حوالة واردة)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رصيدك[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'(?:الرصيد|رصيدك)\s*(?:الحالي\s*)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 4. Muhafazati (محفظتي)
    WalletSmsTemplate(
      walletType: 'muhafazati',
      walletNameAr: 'محفظتي',
      senderIds: ['Muhafazati', 'MTN', 'Spacetel', 'محفظتي', 'YOU', 'يو'],
      incomePatterns: [
        RegExp(r'(?:تم استلام|إيداع|ايداع|تمت إضافة|أضيف|اضيف)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم|تم\s*تحويل|تم\s*سداد|سداد|شراء|مشتريات|تم\s*شراء|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رصيدك[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'(?:الرصيد|رصيدك)\s*(?:الحالي\s*)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 5. Jawali (جوالي - كاك بنك / يمن موبايل)
    WalletSmsTemplate(
      walletType: 'jawali',
      walletNameAr: 'جوالي',
      senderIds: ['Jawali', 'YemenMobile', 'CACBank', 'CAC_Bank', 'جوالي', 'CAC'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تحويل لحسابك|أودع|اودع|اضيف|أضيف)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:تم\s*خصم|خصم|تم\s*سداد|سداد فاتورة|سداد|تم\s*تحويل|سحب|شراء|مشتريات|تم\s*شراء|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رصيدك[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'(?:الرصيد|رصيدك)\s*(?:الحالي\s*)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 6. OneCash (ون كاش - بنك القطيبي)
    WalletSmsTemplate(
      walletType: 'onecash',
      walletNameAr: 'ون كاش',
      senderIds: ['OneCash', 'ONECASH', 'onecash', 'ون كاش', 'القطيبي', 'AlQutaibi', 'Qutaibi'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|تحويل وارد|حوالة واردة)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
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
      senderIds: ['AlAmqi', 'Alamqi', 'ALAMQI', 'العمقي', 'AMQI', 'Amqi'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|تحويل وارد|حوالة واردة)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
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
      senderIds: ['Floosak', 'FLOOSAK', 'floosak', 'فلوسك', 'YBR'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف|تحويل وارد|حوالة واردة)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false, dotAll: true),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم\s*خصم|تم\s*سداد|تم\s*تحويل|سداد|سحب|تم\s*سحب|تم\s*شراء|شراء|مشتريات|دفع|تم\s*دفع)[\s\S]*?(?:(?:ب?مبلغ|ب?قيمة)\s*)?(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'(?:الرصيد|رصيدك|رصيد)\s*(?:الحالي|المتاح|المتبقي|الفعلي|هو)?[:\s]*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'رصيد\s*(?:حسابك)?(?:\s+في\s+[^\d]+)?\s*(?:هو|:)?\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|ريال|\$)\s*رصيدك', caseSensitive: false),
      ],
    ),
  ];

  /// Normalize Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) to standard ASCII digits (0-9)
  static String normalizeDigits(String input) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const ascii = '0123456789';
    var res = input;
    for (int i = 0; i < arabicIndic.length; i++) {
      res = res.replaceAll(arabicIndic[i], ascii[i]);
    }
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

  /// Find matching template for a given SMS sender address
  static WalletSmsTemplate? findTemplate(String sender, [Map<String, String>? customMappings]) {
    final cleanSender = sender.trim().toLowerCase();
    final all = getAllTemplates();

    // Check custom mappings first (e.g. user mapped a number/contact to wallet type)
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

    for (final template in all) {
      for (final id in template.senderIds) {
        if (cleanSender.contains(id.toLowerCase()) || id.toLowerCase().contains(cleanSender)) {
          return template;
        }
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
      RegExp(r'(?:المرجع|مرجع|ref(?:erence)?|رقم\s*العملية|رقم\s*المرجع|رقم\s*الحوالة|رقم\s*[إا]شعار|رقم\s*ال[إا]شعار|ال[إا]شعار|[إا]شعار\s*رقم|رقم\s*السند|رقم\s*الحركة|عملية\s*رقم|حركة\s*رقم)[\s:]*([0-9a-zA-Z]+)', caseSensitive: false),
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
    final template = findTemplate(sender, customMappings);
    if (template == null) return null;

    final normalized = normalizeDigits(body);

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
      final isExp = textWithoutBalance.contains('خصم') ||
          textWithoutBalance.contains('شراء') ||
          textWithoutBalance.contains('مشتريات') ||
          textWithoutBalance.contains('سداد') ||
          textWithoutBalance.contains('دفع') ||
          textWithoutBalance.contains('حاسب') ||
          textWithoutBalance.contains('سحب');

      final isInc = textWithoutBalance.contains('أودع') ||
          textWithoutBalance.contains('اودع') ||
          textWithoutBalance.contains('إيداع') ||
          textWithoutBalance.contains('ايداع') ||
          textWithoutBalance.contains('أضيف') ||
          textWithoutBalance.contains('اضيف') ||
          textWithoutBalance.contains('استلام') ||
          textWithoutBalance.contains('تحويل وارد');

      if (isExp || isInc) {
        final fallbackPatterns = [
          RegExp(r'(?:ب?مبلغ|ب?قيمة)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)?', caseSensitive: false),
          RegExp(r'(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
          RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*(?:YER|SAR|USD|ر\.?ي|ر\.?س|\$)', caseSensitive: false),
        ];

        for (final p in fallbackPatterns) {
          final m = p.firstMatch(textWithoutBalance);
          if (m != null && m.groupCount >= 1) {
            final raw = m.group(1);
            if (raw != null) {
              final parsedVal = parseAmount(raw);
              if (parsedVal != null && parsedVal > 0) {
                amount = parsedVal;
                type = isExp ? 'expense' : 'income';
                break;
              }
            }
          }
        }
      }
    }

    final refNumber = extractReferenceNumber(body);
    final smsKey = generateSmsKey(sender, date, body);

    // Disambiguation: Pure balance inquiry / statement notification
    if (amount == null || type == null) {
      if (balance != null) {
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
