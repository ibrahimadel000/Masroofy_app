import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';

class DemoDataSeeder {
  static Future<void> seedDemoData({
    required WalletRepository walletRepository,
    required TransactionRepository transactionRepository,
  }) async {
    final now = DateTime.now();

    // 1. Create 3 Yemeni Wallets
    final w1 = Wallet(
      id: 'demo_kuraimi',
      name: 'كريمي كاش (الحساب الجاري)',
      type: 'kuraimi',
      colorValue: 0xFF0E7C61,
      iconCodePoint: Icons.account_balance_rounded.codePoint,
      openingBalance: 150000.0,
      isFavorite: true,
      createdAt: now.subtract(const Duration(days: 35)),
    );

    final w2 = Wallet(
      id: 'demo_jaib',
      name: 'محفظة جيب',
      type: 'jaib',
      colorValue: 0xFF1E88E5,
      iconCodePoint: Icons.wallet_rounded.codePoint,
      openingBalance: 40000.0,
      isFavorite: true,
      createdAt: now.subtract(const Duration(days: 35)),
    );

    final w3 = Wallet(
      id: 'demo_kash',
      name: 'محفظة كاش (MTN/يو)',
      type: 'kash',
      colorValue: 0xFFF57C00,
      iconCodePoint: Icons.payments_rounded.codePoint,
      openingBalance: 20000.0,
      isFavorite: false,
      createdAt: now.subtract(const Duration(days: 35)),
    );

    await walletRepository.saveWallet(w1);
    await walletRepository.saveWallet(w2);
    await walletRepository.saveWallet(w3);

    // 2. Create 20 realistic transactions over the last 30 days
    final List<Map<String, dynamic>> rawTxData = [
      // Week 4 ago (Days 25 - 28)
      {
        'wId': w1.id,
        'type': 'income',
        'amount': 220000.0,
        'category': 'راتب',
        'note': 'إيداع مرتب شهر سبتمبر 2026',
        'daysAgo': 28,
        'source': 'sms',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 18000.0,
        'category': 'بقالة',
        'note': 'تموينات البركة المركزية',
        'daysAgo': 26,
        'source': 'manual',
      },
      {
        'wId': w2.id,
        'type': 'expense',
        'amount': 4500.0,
        'category': 'فواتير',
        'note': 'سداد باقة فورجي يمن موبايل',
        'daysAgo': 25,
        'source': 'sms',
      },
      // Week 3 ago (Days 18 - 22)
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 12000.0,
        'category': 'مواصلات',
        'note': 'تعبئة بترول سيارة',
        'daysAgo': 22,
        'source': 'manual',
      },
      {
        'wId': w3.id,
        'type': 'income',
        'amount': 25000.0,
        'category': 'تحويل',
        'note': 'حوالة واردة من الأخ أحمد',
        'daysAgo': 21,
        'source': 'sms',
      },
      {
        'wId': w2.id,
        'type': 'expense',
        'amount': 3800.0,
        'category': 'أكل',
        'note': 'وجبة غداء مطعم ريمان',
        'daysAgo': 20,
        'source': 'manual',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 7500.0,
        'category': 'بقالة',
        'note': 'خضروات وفواكه الأمانة',
        'daysAgo': 19,
        'source': 'manual',
      },
      // Week 2 ago (Days 10 - 15)
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 6000.0,
        'category': 'فواتير',
        'note': 'سداد اشتراك كهرباء تجاري',
        'daysAgo': 15,
        'source': 'sms',
      },
      {
        'wId': w2.id,
        'type': 'expense',
        'amount': 2400.0,
        'category': 'أكل',
        'note': 'عشاء مطعم الشيباني',
        'daysAgo': 14,
        'source': 'manual',
      },
      {
        'wId': w3.id,
        'type': 'expense',
        'amount': 3500.0,
        'category': 'مواصلات',
        'note': 'مشاوير تاكسي داخل المدينة',
        'daysAgo': 12,
        'source': 'manual',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 9500.0,
        'category': 'بقالة',
        'note': 'سوبرماركت المدينة',
        'daysAgo': 11,
        'source': 'sms',
      },
      // Last 7 days (This Week)
      {
        'wId': w2.id,
        'type': 'income',
        'amount': 15000.0,
        'category': 'تحويل',
        'note': 'تحويل مشترك جيب',
        'daysAgo': 6,
        'source': 'sms',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 4200.0,
        'category': 'أكل',
        'note': 'كافتيريا الأندلس',
        'daysAgo': 5,
        'source': 'manual',
      },
      {
        'wId': w2.id,
        'type': 'expense',
        'amount': 1500.0,
        'category': 'فواتير',
        'note': 'تسديد رصيد هاتف منزلي',
        'daysAgo': 4,
        'source': 'sms',
      },
      {
        'wId': w3.id,
        'type': 'expense',
        'amount': 2000.0,
        'category': 'مواصلات',
        'note': 'مواصلات دوام',
        'daysAgo': 3,
        'source': 'manual',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 11000.0,
        'category': 'بقالة',
        'note': 'أغراض منزلية تموينات الهدى',
        'daysAgo': 2,
        'source': 'manual',
      },
      {
        'wId': w2.id,
        'type': 'expense',
        'amount': 3200.0,
        'category': 'أكل',
        'note': 'وجبة شاورما ومعجنات',
        'daysAgo': 1,
        'source': 'manual',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 1500.0,
        'category': 'فواتير',
        'note': 'سداد يمن موبايل 772004664',
        'daysAgo': 1,
        'source': 'sms',
      },
      {
        'wId': w1.id,
        'type': 'expense',
        'amount': 2800.0,
        'category': 'أخرى',
        'note': 'شراء صيدلية ومستلزمات طبية',
        'daysAgo': 0,
        'source': 'manual',
      },
      {
        'wId': w2.id,
        'type': 'expense',
        'amount': 2000.0,
        'category': 'مواصلات',
        'note': 'مشوار سريع',
        'daysAgo': 0,
        'source': 'sms',
      },
    ];

    for (final raw in rawTxData) {
      final daysAgo = raw['daysAgo'] as int;
      final txDate = now.subtract(Duration(days: daysAgo, hours: daysAgo * 2 % 12));
      final tx = TransactionModel(
        id: const Uuid().v4(),
        walletId: raw['wId'] as String,
        type: raw['type'] as String,
        amount: (raw['amount'] as num).toDouble(),
        category: raw['category'] as String,
        note: raw['note'] as String,
        date: txDate,
        source: raw['source'] as String,
        smsKey: raw['source'] == 'sms' ? 'demo_sms_${raw['wId']}_$daysAgo' : null,
        createdAt: txDate,
      );
      await transactionRepository.saveTransaction(tx);
    }
  }
}
