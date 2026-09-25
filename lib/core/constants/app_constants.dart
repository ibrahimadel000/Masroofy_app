import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppConstants {
  // Wallet Types
  static const Map<String, String> walletTypes = {
    'kuraimi': 'الكريمي',
    'jeeb': 'جيب',
    'kash': 'كاش',
    'muhafazati': 'محفظتي',
    'jawali': 'جوالي',
    'other': 'أخرى',
  };

  // Transaction Categories
  static const List<String> categories = [
    'أكل',
    'مواصلات',
    'بقالة',
    'فواتير',
    'تحويل',
    'راتب',
    'أخرى',
  ];

  // Category Icon Mapping
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'أكل':
        return Icons.restaurant_rounded;
      case 'مواصلات':
        return Icons.directions_bus_rounded;
      case 'بقالة':
        return Icons.shopping_cart_rounded;
      case 'فواتير':
        return Icons.receipt_long_rounded;
      case 'تحويل':
        return Icons.swap_horiz_rounded;
      case 'راتب':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // Wallet Preset Colors
  static const List<Color> walletColors = [
    Color(0xFF0E7C61), // Mizaan Emerald
    Color(0xFF1B62CD), // Kash Blue
    Color(0xFF8E24AA), // Muhafazati Purple
    Color(0xFFE5A93C), // Jawali Amber
    Color(0xFFD32F2F), // Red
    Color(0xFF455A64), // Blue Grey
  ];

  // Wallet Preset Icons
  static const List<IconData> walletIcons = [
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.payments_rounded,
    Icons.account_balance_rounded,
    Icons.currency_exchange_rounded,
  ];

  static IconData getWalletIcon(int codePoint) {
    for (final icon in walletIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
    return Icons.account_balance_wallet_rounded;
  }

  // Currencies
  static const Map<String, String> currencySymbols = {
    'YER': 'ر.ي',
    'SAR': 'ر.س',
    'USD': '\$',
  };

  static const Map<String, String> currencyNames = {
    'YER': 'ريال يمني (YER)',
    'SAR': 'ريال سعودي (SAR)',
    'USD': 'دولار أمريكي (USD)',
  };

  static const List<String> arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> arabicWeekdaysShort = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  // Number / Currency Formatter
  static String formatCurrency(double amount, [String currencyCode = 'YER']) {
    try {
      final formatter = NumberFormat('#,##0.##', 'ar');
      final symbol = currencySymbols[currencyCode] ?? 'ر.ي';
      return '${formatter.format(amount)} $symbol';
    } catch (_) {
      final symbol = currencySymbols[currencyCode] ?? 'ر.ي';
      return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $symbol';
    }
  }

  // Date Formatter
  static String formatDate(DateTime date) {
    try {
      final formatter = DateFormat('yyyy/MM/dd', 'ar');
      return formatter.format(date);
    } catch (_) {
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return '${date.year}/$m/$d';
    }
  }

  static String formatMonthYear(DateTime date) {
    try {
      return DateFormat('MMMM yyyy', 'ar').format(date);
    } catch (_) {
      final month = arabicMonths[(date.month - 1) % 12];
      return '$month ${date.year}';
    }
  }

  static String formatShortWeekday(DateTime date) {
    try {
      return DateFormat('E', 'ar').format(date);
    } catch (_) {
      return arabicWeekdaysShort[(date.weekday - 1) % 7];
    }
  }

  // Time Formatter (12-hour format in Arabic: 08:30 م / 10:15 ص)
  static String formatTime(DateTime date) {
    try {
      final formatter = DateFormat('hh:mm a', 'ar');
      return formatter.format(date);
    } catch (_) {
      final int hour = date.hour;
      final int minute = date.minute;
      final isPm = hour >= 12;
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final h = displayHour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      final period = isPm ? 'م' : 'ص';
      return '$h:$m $period';
    }
  }

  // Combined Date and Time Formatter
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)}  •  ${formatTime(date)}';
  }
}
