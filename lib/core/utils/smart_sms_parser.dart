import 'package:mizaan/core/constants/sms_senders.dart';

/// Result of smart analysis of any arbitrary SMS from any bank/wallet worldwide
class SmartSmsAnalysisResult {
  final double? amount;
  final double? balance;
  final String? type; // 'income' | 'expense' | 'adjustment'
  final bool isBalanceOnly;
  final String? currency;
  final String? detectedSender;
  final String? suggestedWalletName;
  final WalletSmsTemplate? generatedTemplate;

  const SmartSmsAnalysisResult({
    this.amount,
    this.balance,
    this.type,
    this.isBalanceOnly = false,
    this.currency,
    this.detectedSender,
    this.suggestedWalletName,
    this.generatedTemplate,
  });

  bool get isSuccess =>
      (amount != null && type != null) || (isBalanceOnly && balance != null);
}

/// Universal Smart SMS Parser & Template Generator
/// Enables users anywhere in the world to input an SMS from their bank and automatically
/// extract transaction amount, balance, and generate a dynamic template with zero developer intervention.
class SmartSmsParser {
  /// Known currencies and symbols across GCC, Arab countries, and global markets
  static const List<String> globalCurrencies = [
    'YER', 'SAR', 'USD', 'EUR', 'GBP', 'AED', 'EGP', 'QAR', 'KWD', 'BHD', 'OMR', 'JOD',
    'TRY', 'CAD', 'AUD', 'INR', 'PKR', 'MAD', 'DZD', 'TND', 'IQD', 'LBP', 'SDG',
    'ر.ي', 'ر.س', 'د.إ', 'ج.م', 'د.ك', 'ر.ق', 'د.ب', 'ر.ع', 'د.أ', 'ل.ل',
    r'$', '€', '£', '¥'
  ];

  /// Standard currency regex component
  static const String currencyPattern =
      r'(?:YER|SAR|USD|EUR|GBP|AED|EGP|QAR|KWD|BHD|OMR|JOD|TRY|CAD|AUD|INR|PKR|MAD|DZD|TND|IQD|LBP|SDG|ر\.?ي|ر\.?س|د\.?إ|ج\.?م|د\.?ك|ر\.?ق|د\.?ب|ر\.?ع|د\.?أ|ل\.?ل|\$|€|£|¥)';

  /// Balance indicator keywords in Arabic and English
  static const List<String> balanceKeywords = [
    'رصيدك', 'الرصيد', 'رصيد', 'رص:', 'رص',
    'الرصيد المتاح', 'الرصيد المتوفر', 'الرصيد الحالي', 'الرصيد المتبقي',
    'available balance', 'avail bal', 'avail balance', 'current balance',
    'cur bal', 'account balance', 'acct bal', 'new balance', 'balance is', 'balance:', 'bal:', 'bal'
  ];

  /// Income indicator keywords in Arabic and English
  static const List<String> incomeKeywords = [
    'إيداع', 'ايداع', 'الإيداع', 'الايداع', 'تم إيداع', 'تم ايداع', 'إيداع نقدي', 'ايداع نقدي',
    'أودع', 'اودع', 'أودعت', 'اودعت', 'أودع لك', 'اودع لك',
    'تم استلام', 'استلام', 'وارد', 'تحويل وارد', 'حوالة واردة', 'حواله وارده', 'حوالة من', 'حواله من',
    'اضيف', 'أضيف', 'أضيفت', 'اضيفت', 'إضافة', 'اضافة', 'إضافه', 'اضافه', 'تمت إضافة', 'تمت اضافه',
    'تغذية', 'تغذيه', 'تمت تغذية', 'تمت تغذيه', 'تم تغذية', 'تم تغذيه',
    'قيد لحسابك', 'قيد لحسابكم', 'قيد في حسابك', 'قيد في حسابكم', 'تم قيد', 'تم القيد',
    'تحويل لحسابك', 'تحويل لحسابكم', 'تحويل إلى محفظتك', 'تحويل الى محفظتك', 'تحويل إلى حسابك', 'تحويل الى حسابك',
    'تحويل لك', 'وصلك تحويل', 'وصلتك حوالة', 'وصلتك حواله', 'وصلك مبلغ',
    'شحن', 'قبض', 'توريد', 'لحسابك', 'لحسابكم',
    'دائن', 'اشعار دائن', 'إشعار دائن', 'عكس قيد', 'لصالحك',
    'credited', 'credit', 'deposited', 'deposit', 'received', 'transfer in', 'added'
  ];

  /// Expense indicator keywords in Arabic and English
  static const List<String> expenseKeywords = [
    'خصم', 'تم خصم', 'سداد', 'تم سداد', 'سحب', 'تم سحب',
    'شراء', 'تم شراء', 'مشتريات', 'دفع', 'تم دفع', 'تحويل', 'تم تحويل',
    'debited', 'debit', 'spent', 'paid', 'payment', 'withdrawn', 'purchase',
    'transfer to', 'transferred', 'charge', 'deducted'
  ];

  /// Analyze any raw SMS body from any bank in the world
  static SmartSmsAnalysisResult analyzeSms({
    required String body,
    String? sender,
    String? customWalletName,
  }) {
    final normalized = SmsSenderRegistry.normalizeDigits(body);

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
        normalized.contains('دائن') ||
        normalized.contains('لصالحك') ||
        normalized.contains('balance') ||
        normalized.contains('account') ||
        normalized.contains('deposit');

    if (isPromo && !hasBankAnchor) {
      return const SmartSmsAnalysisResult();
    }

    final detectedCurrency = detectCurrency(normalized);

    // Pass 1: Extract Balance and isolate its position
    final balanceMatch = _extractBalance(normalized);
    final double? balance = balanceMatch?.amount;
    String textWithoutBalance = normalized;

    if (balanceMatch != null) {
      textWithoutBalance = normalized.replaceRange(
        balanceMatch.startIndex,
        balanceMatch.endIndex,
        ' ',
      );
    }

    // Pass 2: Extract Transaction Operation Amount from masked text
    final operationMatch = _extractOperation(textWithoutBalance);

    final double? amount = operationMatch?.amount;
    final String? type = operationMatch?.type;
    final bool isBalanceOnly = (amount == null || amount <= 0) && (balance != null);

    final finalType = isBalanceOnly ? 'adjustment' : type;
    final finalAmount = isBalanceOnly ? 0.0 : amount;

    // Generate a reusable WalletSmsTemplate if analysis was successful
    WalletSmsTemplate? generatedTemplate;
    final cleanSender = (sender ?? 'bank').trim();
    final walletType = cleanSender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final walletName = customWalletName ?? cleanSender;

    if (finalType != null) {
      generatedTemplate = buildTemplate(
        walletType: walletType.isEmpty ? 'custom_wallet' : walletType,
        walletNameAr: walletName.isEmpty ? 'محفظة مخصصة' : walletName,
        senderId: cleanSender,
        detectedCurrency: detectedCurrency,
      );
    }

    return SmartSmsAnalysisResult(
      amount: finalAmount,
      balance: balance,
      type: finalType,
      isBalanceOnly: isBalanceOnly,
      currency: detectedCurrency,
      detectedSender: cleanSender,
      suggestedWalletName: walletName,
      generatedTemplate: generatedTemplate,
    );
  }

  /// Detect currency symbol or code from text
  static String? detectCurrency(String text) {
    for (final curr in globalCurrencies) {
      final escaped = RegExp.escape(curr);
      final pattern = RegExp('(?<=^|\\s|\\d)$escaped(?=\\s|\\d|\$)', caseSensitive: false);
      if (pattern.hasMatch(text) || text.contains(curr)) {
        return curr;
      }
    }
    return null;
  }

  /// Pass 1: Balance Extraction
  static _NumberSpan? _extractBalance(String text) {
    final patterns = [
      // 1. Direct balance with optional qualifiers (الحالي, المتاح, المتوفر, المتبقي, etc.):
      // e.g. "رصيدك الحالي 5200 USD", "رصيدك YER 4,045.30", "الرصيد: 3000 ر.س", "Avail Bal: $1,250"
      RegExp(
        r'(?:الرصيد|رصيدك|رصيد|رص:?|balance|avail bal|available balance|cur bal|new balance)\s*(?:حسابك)?\s*(?:الحالي|المتوفر|المتاح|المتبقي|الفعلي|الجديد|الآن|الان|طرفنا|هو|is|:|=)*[\s:]*(?:' + currencyPattern + r')?[\s:]*([0-9,]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ),
      // 2. Intervening clause: "available balance for account ending in 9876 is USD 3,500.00"
      RegExp(
        r'(?:الرصيد|رصيدك|رصيد|balance|avail bal|available balance)[\s\S]*?(?:هو|is|:|=)[\s:]*(?:' + currencyPattern + r')?[\s:]*([0-9,]+(?:\.[0-9]+)?)',
        caseSensitive: false,
        dotAll: true,
      ),
      // 3. Suffix balance: "4,045.30 YER رصيدك", "$1,250 Avail Bal" (must NOT be preceded by بمبلغ/بقيمة/amount)
      RegExp(
        r'(?<!(?:ب?مبلغ|ب?قيمة|amount)\s*)([0-9,]+(?:\.[0-9]+)?)\s*(?:' + currencyPattern + r')+\s*(?:الرصيد|رصيدك|رصيد|balance|bal)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        for (int g = 1; g <= match.groupCount; g++) {
          final groupVal = match.group(g);
          if (groupVal != null) {
            final parsed = SmsSenderRegistry.parseAmount(groupVal);
            if (parsed != null) {
              return _NumberSpan(
                amount: parsed,
                startIndex: match.start,
                endIndex: match.end,
              );
            }
          }
        }
      }
    }

    return null;
  }

  /// Pass 2: Operation Amount & Type Extraction
  static _OperationResult? _extractOperation(String text) {
    final incKw = incomeKeywords.map(RegExp.escape).join('|');
    // Check Income patterns in hierarchical tiers
    final incomePatterns = [
      // Tier 1: Income Keyword followed by explicit amount indicator: (أودع ... بمبلغ 30,000)
      RegExp(
        '(?:$incKw)[\\s\\S]*?(?:ب?مبلغ|ب?قيمة|amount|with|by)[\\s:]*(?:$currencyPattern)?[\\s:]*([0-9,]+(?:\\.[0-9]+)?)',
        caseSensitive: false,
        dotAll: true,
      ),
      // Tier 2: Inward transfer pattern (amount before destination clause: تم تحويل 8000 إلى محفظتك)
      RegExp(
        r'(?:تم\s+)?(?:تحويل|توريد|إيداع|ايداع|أودع|اودع|قيد)\s+(?:مبلغ\s+)?([0-9,]+(?:\.[0-9]+)?)\s*(?:' + currencyPattern + r')?\s*(?:إلى|الى|في|لحساب|لك)',
        caseSensitive: false,
      ),
      // Tier 3: Keyword followed directly by currency and amount (excluding 9-digit phone numbers)
      RegExp(
        '(?:$incKw)[\\s:]*(?:$currencyPattern)[\\s:]*([0-9,]+(?:\\.[0-9]+)?)',
        caseSensitive: false,
      ),
      RegExp(
        '(?:$incKw)[\\s:]*(?<!\\d)(?!(?:7[01378]\\d{7}))([0-9,]+(?:\\.[0-9]+)?)[\\s:]*(?:$currencyPattern)',
        caseSensitive: false,
      ),
      // Tier 4: Suffix: Amount followed by currency and keyword
      RegExp(
        '(?<!\\d)(?!(?:7[01378]\\d{7}))([0-9,]+(?:\\.[0-9]+)?)[\\s:]*(?:$currencyPattern)?[\\s:]*(?:$incKw)',
        caseSensitive: false,
      ),
      // Tier 5: General keyword match excluding phone numbers
      RegExp(
        '(?:$incKw)[\\s\\S]*?(?<!\\d)(?!(?:7[01378]\\d{7}))([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]+)?|[0-9]+(?:\\.[0-9]+)?)(?!\\d)',
        caseSensitive: false,
        dotAll: true,
      ),
    ];

    for (final p in incomePatterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        for (int g = 1; g <= match.groupCount; g++) {
          final groupVal = match.group(g);
          if (groupVal != null) {
            final parsed = SmsSenderRegistry.parseAmount(groupVal);
            if (parsed != null && parsed > 0) {
              return _OperationResult(amount: parsed, type: 'income');
            }
          }
        }
      }
    }

    final hasInwardTarget = text.contains('لحسابك') ||
        text.contains('لحسابكم') ||
        text.contains('إلى حسابك') ||
        text.contains('الى حسابك') ||
        text.contains('في حسابك') ||
        text.contains('في حسابكم') ||
        text.contains('إلى محفظتك') ||
        text.contains('الى محفظتك') ||
        text.contains('لك');

    final activeExpenseKeywords = expenseKeywords.where((kw) {
      if ((kw == 'تحويل' || kw == 'تم تحويل' || kw == 'transferred' || kw == 'transfer to') && hasInwardTarget) {
        return false;
      }
      return true;
    }).toList();

    final expKw = activeExpenseKeywords.map(RegExp.escape).join('|');
    // Check Expense patterns in hierarchical tiers
    final expensePatterns = [
      // Tier 1: Expense Keyword followed by explicit amount indicator: (تم سداد مبلغ 250.00)
      RegExp(
        '(?:$expKw)[\\s\\S]*?(?:ب?مبلغ|ب?قيمة|amount|for|with)[\\s:]*(?:$currencyPattern)?[\\s:]*([0-9,]+(?:\\.[0-9]+)?)',
        caseSensitive: false,
        dotAll: true,
      ),
      // Tier 2: Keyword directly followed by currency and amount
      RegExp(
        '(?:$expKw)[\\s:]*(?:$currencyPattern)[\\s:]*([0-9,]+(?:\\.[0-9]+)?)',
        caseSensitive: false,
      ),
      RegExp(
        '(?:$expKw)[\\s:]*(?<!\\d)(?!(?:7[01378]\\d{7}))([0-9,]+(?:\\.[0-9]+)?)[\\s:]*(?:$currencyPattern)',
        caseSensitive: false,
      ),
      // Tier 3: Suffix
      RegExp(
        '(?<!\\d)(?!(?:7[01378]\\d{7}))([0-9,]+(?:\\.[0-9]+)?)[\\s:]*(?:$currencyPattern)?[\\s:]*(?:$expKw)',
        caseSensitive: false,
      ),
      // Tier 4: General fallback excluding phone numbers
      RegExp(
        '(?:$expKw)[\\s\\S]*?(?<!\\d)(?!(?:7[01378]\\d{7}))([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]+)?|[0-9]+(?:\\.[0-9]+)?)(?!\\d)',
        caseSensitive: false,
        dotAll: true,
      ),
    ];

    for (final p in expensePatterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        for (int g = 1; g <= match.groupCount; g++) {
          final groupVal = match.group(g);
          if (groupVal != null) {
            final parsed = SmsSenderRegistry.parseAmount(groupVal);
            if (parsed != null && parsed > 0) {
              return _OperationResult(amount: parsed, type: 'expense');
            }
          }
        }
      }
    }

    return null;
  }

  /// Automatically build a robust, reusable WalletSmsTemplate from extracted parameters
  static WalletSmsTemplate buildTemplate({
    required String walletType,
    required String walletNameAr,
    required String senderId,
    String? detectedCurrency,
  }) {
    final currRegex = currencyPattern;

    final incomeStrings = [
      '(?:إيداع|ايداع|تم إيداع|تم استلام|وارد|حوالة واردة|اضيف|أضيف|أودع|اودع|credited|deposit|deposited|received)[\\s\\S]*?(?:ب?مبلغ|ب?قيمة|amount|with)\\s*'
          '$currRegex?\\s*([0-9,]+(?:\\.[0-9]+)?)',
      r'(?:تم\s+)?(?:تحويل|توريد|إيداع|ايداع)\s+(?:مبلغ\s+)?([0-9,]+(?:\.[0-9]+)?)\s*'
          '$currRegex?\\s*(?:إلى|الى|في|لحساب)',
      '(?:إيداع|ايداع|تم إيداع|تم استلام|وارد|حوالة واردة|اضيف|أضيف|أودع|اودع|credited|deposit|deposited|received)[\\s\\S]*?'
          '$currRegex\\s*([0-9,]+(?:\\.[0-9]+)?)',
      r'(?<!\d)(?!(?:7[01378]\d{7}))([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]+)?|[0-9]+(?:\.[0-9]+)?)\s*'
          '$currRegex\\s*(?:إيداع|ايداع|أودع|اضيف|وارد)',
    ];

    final expenseStrings = [
      '(?:خصم|تم خصم|سداد|تم سداد|سحب|تم سحب|شراء|تم شراء|مشتريات|تحويل|debited|spent|paid|payment|withdrawn|purchase)[\\s\\S]*?(?:ب?مبلغ|ب?قيمة|amount|for)\\s*'
          '$currRegex?\\s*([0-9,]+(?:\\.[0-9]+)?)',
      '(?:خصم|تم خصم|سداد|تم سداد|سحب|تم سحب|شراء|تم شراء|مشتريات|تحويل|debited|spent|paid|payment|withdrawn|purchase)[\\s\\S]*?'
          '$currRegex\\s*([0-9,]+(?:\\.[0-9]+)?)',
      r'(?<!\d)(?!(?:7[01378]\d{7}))([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]+)?|[0-9]+(?:\.[0-9]+)?)\s*'
          '$currRegex\\s*(?:خصم|شراء|سداد|سحب)',
    ];

    final balanceStrings = [
      '(?:رصيدك|الرصيد|رصيد|رص|balance|avail bal|available balance)[\\s:]*(?:الحالي|المتبقي|المتوفر|المتاح|هو|is|:)?\\s*'
          '$currRegex?\\s*([0-9,]+(?:\\.[0-9]+)?)',
      '([0-9,]+(?:\\.[0-9]+)?)\\s*$currRegex+\\s*(?:رصيدك|رص|balance|bal)',
    ];

    return WalletSmsTemplate.fromStrings(
      walletType: walletType,
      walletNameAr: walletNameAr,
      senderIds: [senderId],
      incomePatterns: incomeStrings,
      expensePatterns: expenseStrings,
      balancePatterns: balanceStrings,
    );
  }
}

class _NumberSpan {
  final double amount;
  final int startIndex;
  final int endIndex;

  _NumberSpan({
    required this.amount,
    required this.startIndex,
    required this.endIndex,
  });
}

class _OperationResult {
  final double amount;
  final String type;

  _OperationResult({
    required this.amount,
    required this.type,
  });
}
