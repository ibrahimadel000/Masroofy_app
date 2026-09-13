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

  // Number / Currency Formatter
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.##', 'ar');
    return '${formatter.format(amount)} ر.ي';
  }

  static String formatDate(DateTime date) {
    final formatter = DateFormat('yyyy/MM/dd', 'ar');
    return formatter.format(date);
  }
}
