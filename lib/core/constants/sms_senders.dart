class ParsedSmsData {
  final String walletType;
  final String type; // 'income' | 'expense'
  final double amount;
  final double? balance;
  final String category;
  final DateTime date;
  final String rawSender;
  final String rawBody;
  final String smsKey;

  const ParsedSmsData({
    required this.walletType,
    required this.type,
    required this.amount,
    this.balance,
    required this.category,
    required this.date,
    required this.rawSender,
    required this.rawBody,
    required this.smsKey,
  });
}

class WalletSmsTemplate {
  final String walletType;
  final String walletNameAr;
  final List<String> senderIds;
  final List<RegExp> incomePatterns;
  final List<RegExp> expensePatterns;
  final List<RegExp> balancePatterns;

  const WalletSmsTemplate({
    required this.walletType,
    required this.walletNameAr,
    required this.senderIds,
    required this.incomePatterns,
    required this.expensePatterns,
    required this.balancePatterns,
  });
}

class SmsSenderRegistry {
  static final List<WalletSmsTemplate> defaultTemplates = [
    // 1. Kuraimi Bank (الكريمي)
    // Real SMS samples:
    // "أودع/عادل عبدالواحد لحسابك50,000.00 YER 51,245.30YERرصيدك"
    // "تم سداد 400.00 جوال 772004664 YER 2,545.30 رصيدك"
    // "تم تحويل1,100.00لحساب خليل الرحمن رصيدك1,445.30YER"
    WalletSmsTemplate(
      walletType: 'kuraimi',
      walletNameAr: 'الكريمي',
      senderIds: ['KuraimiMB', 'KuraimiIMB', 'Kuraimi', 'KURAIMI', 'الكريمي'],
      incomePatterns: [
        RegExp(r'[أا]ودع.*?لحسابك\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'تم سداد\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'تم تحويل\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
        RegExp(r'تم خصم\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'(?:YER\s*)?([0-9,]+(?:\.[0-9]+)?)\s*YER\s*رصيدك', caseSensitive: false),
        RegExp(r'رصيدك\s*(?:YER\s*)?([0-9,]+(?:\.[0-9]+)?)\s*(?:YER)?', caseSensitive: false),
        RegExp(r'YER\s*([0-9,]+(?:\.[0-9]+)?)\s*رصيدك', caseSensitive: false),
        RegExp(r'([0-9,]+(?:\.[0-9]+)?)\s*YERرصيدك', caseSensitive: false),
      ],
    ),

    // 2. Jaib Wallet (جيب - بنك التضامن)
    // Real SMS samples:
    // "اضيف 500ر.ي تحويل مشترك رص:5680ر.ي من سام النزيلي-781563420"
    // "خصم 250ر.ي رص:4330ر.ي للرقم 772004664 سداد يمن موبايل"
    // "خصم 100ر.ي رص:4230ر.ي للرقم 772004664 سداد يمن موبايل"
    // "اضيف 450ر.ي تحويل مشترك رص:480ر.ي من اروى القباطي-777161829"
    WalletSmsTemplate(
      walletType: 'jeeb',
      walletNameAr: 'جيب',
      senderIds: ['Jaib', 'JAIB', 'jaib', 'Jeeb', 'JEEB', 'جيب'],
      incomePatterns: [
        RegExp(r'[أا]ضيف\s*([0-9,]+(?:\.[0-9]+)?)\s*ر\.?ي', caseSensitive: false),
        RegExp(r'(?:إيداع|ايداع|تم استلام|تحويل وارد)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'خصم\s*([0-9,]+(?:\.[0-9]+)?)\s*ر\.?ي', caseSensitive: false),
        RegExp(r'(?:تم سداد|تم تحويل)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رص:\s*([0-9,]+(?:\.[0-9]+)?)\s*ر\.?ي', caseSensitive: false),
      ],
    ),

    // 3. Kash Wallet (كاش - بنك اليمن والكويت)
    WalletSmsTemplate(
      walletType: 'kash',
      walletNameAr: 'كاش',
      senderIds: ['Kash', 'KASH', 'kash', 'YKB', 'كاش'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تم إيداع|أودع|اودع|اضيف|أضيف)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'(?:خصم|تم خصم|تم سداد|تم تحويل|سداد)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رصيدك[:\s]*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 4. Muhafazati (محفظتي)
    WalletSmsTemplate(
      walletType: 'muhafazati',
      walletNameAr: 'محفظتي',
      senderIds: ['Muhafazati', 'MTN', 'Spacetel', 'محفظتي'],
      incomePatterns: [
        RegExp(r'(?:تم استلام|إيداع|ايداع|تمت إضافة)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'(?:تم خصم|خصم|تم تحويل|تم سداد)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رصيدك[:\s]*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
    ),

    // 5. Jawali (جوالي - كاك بنك / يمن موبايل)
    WalletSmsTemplate(
      walletType: 'jawali',
      walletNameAr: 'جوالي',
      senderIds: ['Jawali', 'YemenMobile', 'CACBank', 'CAC_Bank', 'جوالي'],
      incomePatterns: [
        RegExp(r'(?:إيداع|ايداع|تم استلام|تحويل لحسابك|أودع)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      expensePatterns: [
        RegExp(r'(?:تم خصم|خصم|تم سداد|سداد فاتورة|تم تحويل)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
      ],
      balancePatterns: [
        RegExp(r'رصيدك[:\s]*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false),
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

    // Check custom mappings first (e.g. user mapped a number/contact to wallet type)
    if (customMappings != null) {
      for (final entry in customMappings.entries) {
        if (cleanSender == entry.key.trim().toLowerCase()) {
          return defaultTemplates.firstWhere(
            (t) => t.walletType == entry.value,
            orElse: () => defaultTemplates.first,
          );
        }
      }
    }

    for (final template in defaultTemplates) {
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
        text.contains('تموينات')) {
      return 'بقالة';
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

  /// Generate unique deduplication key for an SMS
  static String generateSmsKey(String sender, DateTime date, String body) {
    return '${sender.trim()}_${date.millisecondsSinceEpoch}_${body.trim().hashCode.toRadixString(16)}';
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

    double? amount;
    String? type;

    // Check income first
    for (final pattern in template.incomePatterns) {
      final match = pattern.firstMatch(normalized);
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
        final match = pattern.firstMatch(normalized);
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

    if (amount == null || type == null) {
      return null;
    }

    // Extract balance if present
    double? balance;
    for (final pattern in template.balancePatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        for (int g = 1; g <= match.groupCount; g++) {
          final rawBal = match.group(g);
          if (rawBal != null) {
            final parsedBal = parseAmount(rawBal);
            if (parsedBal != null) {
              balance = parsedBal;
              break;
            }
          }
        }
      }
      if (balance != null) break;
    }

    final category = guessCategory(body);
    final smsKey = generateSmsKey(sender, date, body);

    return ParsedSmsData(
      walletType: template.walletType,
      type: type,
      amount: amount,
      balance: balance,
      category: category,
      date: date,
      rawSender: sender,
      rawBody: body,
      smsKey: smsKey,
    );
  }
}
