import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/notification_service.dart';

class SmsCandidateItem {
  final ParsedSmsData data;
  String? targetWalletId;
  bool isSelected;

  SmsCandidateItem({
    required this.data,
    this.targetWalletId,
    this.isSelected = true,
  });
}

/// Top-level background message handler for telephony
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  await SmsService.processBackgroundIncomingSms(message);
}

class SmsService {
  final Telephony? telephony;
  static bool _isListenerRegistered = false;

  const SmsService({this.telephony});

  Telephony get _instance => telephony ?? Telephony.instance;

  /// Check if SMS read permission is granted (Android only)
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted = await _instance.isSmsCapable;
      if (granted != true) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Request SMS permissions from user
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _instance.requestPhoneAndSmsPermissions;
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Universal smart wallet matching
  /// Matches wallet by: ID -> Type -> Name contains -> Sender ID in name -> Favorite wallet -> First wallet
  static Wallet? findMatchingWallet({
    required List<Wallet> userWallets,
    required String walletType,
    WalletSmsTemplate? template,
  }) {
    if (userWallets.isEmpty) return null;

    final cleanType = walletType.toLowerCase().trim();

    // 1. Exact match on wallet ID
    final byId = userWallets.where((w) => w.id == walletType).toList();
    if (byId.isNotEmpty) return byId.first;

    // 2. Exact match on wallet type
    final byType = userWallets.where((w) => w.type.toLowerCase().trim() == cleanType).toList();
    if (byType.isNotEmpty) return byType.first;

    // 3. Match wallet name with walletType or template details
    final byName = userWallets.where((w) {
      final name = w.name.toLowerCase().trim();
      if (name.contains(cleanType) || cleanType.contains(name)) return true;
      if (template != null) {
        final tmplName = template.walletNameAr.toLowerCase().trim();
        if (name.contains(tmplName) || tmplName.contains(name)) return true;
        for (final id in template.senderIds) {
          if (name.contains(id.toLowerCase()) || id.toLowerCase().contains(name)) return true;
        }
      }
      return false;
    }).toList();
    if (byName.isNotEmpty) return byName.first;

    // 4. Fallback to favorite wallet
    final favorites = userWallets.where((w) => w.isFavorite).toList();
    if (favorites.isNotEmpty) return favorites.first;

    // 5. Fallback to first wallet
    return userWallets.first;
  }

  /// Scan inbox, filter by registered wallet senders only, dedupe, and return candidates
  Future<List<SmsCandidateItem>> scanRecentWalletSms({
    int maxCount = 100,
    required TransactionRepository transactionRepository,
    required List<Wallet> userWallets,
    Map<String, String>? customMappings,
  }) async {
    if (!Platform.isAndroid) return [];

    final List<SmsCandidateItem> results = [];

    try {
      final List<SmsMessage> messages = await _instance.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      final candidates = messages.take(maxCount);

      for (final msg in candidates) {
        final address = msg.address ?? '';
        final body = msg.body ?? '';
        final date = msg.date != null
            ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
            : DateTime.now();

        // 1. Strict Privacy Filter: Skip personal / unregistered senders
        final template = SmsSenderRegistry.findTemplate(address, customMappings);
        if (template == null) continue;

        // 2. Parse transaction details
        final parsed = SmsSenderRegistry.parseMessage(
          sender: address,
          body: body,
          date: date,
          customMappings: customMappings,
        );
        if (parsed == null) continue;

        // 3. Deduplication check: Skip if already imported
        if (transactionRepository.hasSmsKey(parsed.smsKey)) {
          continue;
        }

        // 4. Auto-match with user's wallets dynamically
        final matchedWallet = findMatchingWallet(
          userWallets: userWallets,
          walletType: parsed.walletType,
          template: template,
        );
        final matchedWalletId = matchedWallet?.id;

        results.add(
          SmsCandidateItem(
            data: parsed,
            targetWalletId: matchedWalletId,
            isSelected: true,
          ),
        );
      }
    } catch (_) {
      // Return whatever was collected or empty list
    }

    return results;
  }

  /// Process an incoming message while the app is active in foreground
  Future<TransactionModel?> processIncomingSms({
    required SmsMessage message,
    required TransactionRepository transactionRepository,
    required List<Wallet> userWallets,
    required NotificationService notificationService,
    WalletRepository? walletRepository,
    Map<String, String>? customMappings,
    bool showNotification = true,
  }) async {
    try {
      final sender = message.address ?? '';
      final body = message.body ?? '';
      if (sender.isEmpty || body.isEmpty) return null;

      final template = SmsSenderRegistry.findTemplate(sender, customMappings);
      if (template == null) return null;

      final date = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now();

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: date,
        customMappings: customMappings,
      );
      if (parsed == null) return null;

      if (transactionRepository.hasSmsKey(parsed.smsKey)) return null;
      if (userWallets.isEmpty) return null;

      final matchedWallet = findMatchingWallet(
        userWallets: userWallets,
        walletType: parsed.walletType,
        template: template,
      );
      if (matchedWallet == null) return null;

      final matchedWalletId = matchedWallet.id;
      final walletName = matchedWallet.name;
      final currencyCode = matchedWallet.currencyCode;

      TransactionModel? tx;

      if (parsed.isBalanceOnly) {
        // Pure balance statement / inquiry: reconcile wallet balance directly by adjusting opening balance
        if (parsed.balance != null) {
          final txs = transactionRepository.getTransactionsByWallet(matchedWallet.id);
          final currentBal = BalanceCalculator.calculateWalletBalance(
            openingBalance: matchedWallet.openingBalance,
            transactions: txs,
          );
          final delta = parsed.balance! - currentBal;
          if (delta.abs() >= 0.01) {
            final wRepo = walletRepository ?? WalletRepository();
            final updatedWallet = matchedWallet.copyWith(
              openingBalance: matchedWallet.openingBalance + delta,
            );
            await wRepo.saveWallet(updatedWallet);
          }
        }
      } else {
        // Normal transaction (deposit / expense)
        tx = TransactionModel(
          id: const Uuid().v4(),
          walletId: matchedWalletId,
          type: parsed.type,
          amount: parsed.amount,
          category: parsed.category,
          note: parsed.rawBody,
          date: parsed.date,
          source: 'sms',
          smsKey: parsed.smsKey,
          createdAt: DateTime.now(),
          rawSmsBody: parsed.rawBody,
          rawSmsSender: parsed.rawSender,
        );

        await transactionRepository.saveTransaction(tx);

        // Ground-Truth Wallet Alignment: Align wallet balance silently without creating clutter transactions
        if (parsed.balance != null) {
          final txs = transactionRepository.getTransactionsByWallet(matchedWallet.id);
          final currentBal = BalanceCalculator.calculateWalletBalance(
            openingBalance: matchedWallet.openingBalance,
            transactions: txs,
          );
          final delta = parsed.balance! - currentBal;
          if (delta.abs() >= 0.01) {
            final wRepo = walletRepository ?? WalletRepository();
            final updatedWallet = matchedWallet.copyWith(
              openingBalance: matchedWallet.openingBalance + delta,
            );
            await wRepo.saveWallet(updatedWallet);
          }
        }
      }

      if (showNotification) {
        final prefs = await SharedPreferences.getInstance();
        final uid = DatabaseService.currentUserId ?? 'guest';
        final notifEnabled = prefs.getBool('${uid}_smsNotificationsEnabled') ??
            prefs.getBool('smsNotificationsEnabled') ??
            true;

        if (notifEnabled) {
          await sendTransactionNotification(
            notificationService: notificationService,
            data: parsed,
            walletName: walletName,
            currencyCode: currencyCode,
          );
        }
      }

      return tx;
    } catch (_) {
      return null;
    }
  }

  /// Process an incoming message in the background isolate
  static Future<TransactionModel?> processBackgroundIncomingSms(SmsMessage message) async {
    try {
      final sender = message.address ?? '';
      final body = message.body ?? '';
      if (sender.isEmpty || body.isEmpty) return null;

      final template = SmsSenderRegistry.findTemplate(sender);
      if (template == null) return null;

      final date = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now();

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: date,
      );
      if (parsed == null) return null;

      if (!DatabaseService.isInitialized) {
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getString('current_user_id') ?? 'guest';
        await DatabaseService.init(initialUserId: uid);
      }

      final txRepo = TransactionRepository();
      if (txRepo.hasSmsKey(parsed.smsKey)) return null;

      final walletRepo = WalletRepository();
      final userWallets = walletRepo.getWallets();
      if (userWallets.isEmpty) return null;

      final matchedWallet = findMatchingWallet(
        userWallets: userWallets,
        walletType: parsed.walletType,
        template: template,
      );
      if (matchedWallet == null) return null;

      final matchedWalletId = matchedWallet.id;
      final walletName = matchedWallet.name;
      final currencyCode = matchedWallet.currencyCode;

      TransactionModel? tx;

      if (parsed.isBalanceOnly) {
        if (parsed.balance != null) {
          final txs = txRepo.getTransactionsByWallet(matchedWallet.id);
          final currentBal = BalanceCalculator.calculateWalletBalance(
            openingBalance: matchedWallet.openingBalance,
            transactions: txs,
          );
          final delta = parsed.balance! - currentBal;
          if (delta.abs() >= 0.01) {
            final updatedWallet = matchedWallet.copyWith(
              openingBalance: matchedWallet.openingBalance + delta,
            );
            await walletRepo.saveWallet(updatedWallet);
          }
        }
      } else {
        tx = TransactionModel(
          id: const Uuid().v4(),
          walletId: matchedWalletId,
          type: parsed.type,
          amount: parsed.amount,
          category: parsed.category,
          note: parsed.rawBody,
          date: parsed.date,
          source: 'sms',
          smsKey: parsed.smsKey,
          createdAt: DateTime.now(),
          rawSmsBody: parsed.rawBody,
          rawSmsSender: parsed.rawSender,
        );

        await txRepo.saveTransaction(tx);

        // Ground-Truth Wallet Alignment: Align wallet balance silently without creating clutter transactions
        if (parsed.balance != null) {
          final txs = txRepo.getTransactionsByWallet(matchedWallet.id);
          final currentBal = BalanceCalculator.calculateWalletBalance(
            openingBalance: matchedWallet.openingBalance,
            transactions: txs,
          );
          final delta = parsed.balance! - currentBal;
          if (delta.abs() >= 0.01) {
            final updatedWallet = matchedWallet.copyWith(
              openingBalance: matchedWallet.openingBalance + delta,
            );
            await walletRepo.saveWallet(updatedWallet);
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final uid = DatabaseService.currentUserId ?? 'guest';
      final notifEnabled = prefs.getBool('${uid}_smsNotificationsEnabled') ??
          prefs.getBool('smsNotificationsEnabled') ??
          true;

      if (notifEnabled) {
        final notifService = NotificationService();
        await notifService.init();
        await sendTransactionNotification(
          notificationService: notifService,
          data: parsed,
          walletName: walletName,
          currencyCode: currencyCode,
        );
      }

      return tx;
    } catch (_) {
      return null;
    }
  }

  /// Send instant local notification for an imported transaction
  static Future<void> sendTransactionNotification({
    required NotificationService notificationService,
    required ParsedSmsData data,
    required String walletName,
    required String currencyCode,
  }) async {
    try {
      if (data.isBalanceOnly) {
        final balText = AppConstants.formatCurrency(data.balance ?? 0.0, currencyCode);
        await notificationService.showTransactionAlert(
          title: '🔄 تحديث الرصيد - $walletName',
          body: 'تم تحديث رصيد $walletName الفعلي إلى $balText',
        );
        return;
      }

      final formattedAmount = AppConstants.formatCurrency(data.amount, currencyCode);
      final isExpense = data.type == 'expense';
      final isPurchase = isExpense && (
          data.category == 'بقالة' ||
          data.category == 'مشتريات' ||
          data.rawBody.contains('شراء') ||
          data.rawBody.contains('مشتريات')
      );

      final balanceText = data.balance != null
          ? ' (الرصيد الحالي: ${AppConstants.formatCurrency(data.balance!, currencyCode)})'
          : '';

      final String title;
      final String notifBody;
      if (isExpense) {
        title = isPurchase ? '🛍️ عملية شراء جديدة - $walletName' : '💸 عملية خصم جديدة - $walletName';
        notifBody = 'تم تسجيل عملية ${isPurchase ? "شراء" : "خصم"} بمبلغ $formattedAmount من $walletName$balanceText';
      } else {
        title = '💰 إيداع جديد - $walletName';
        notifBody = 'تم تسجيل إيداع بمبلغ $formattedAmount في $walletName$balanceText';
      }

      await notificationService.showTransactionAlert(title: title, body: notifBody);
    } catch (_) {}
  }

  /// Register telephony listener for incoming SMS (both foreground and background)
  Future<bool> startIncomingSmsListener({
    required TransactionRepository transactionRepository,
    required WalletRepository walletRepository,
    required NotificationService notificationService,
    Function(TransactionModel tx)? onTransactionReceived,
    Map<String, String>? customMappings,
  }) async {
    if (!Platform.isAndroid) return false;
    if (_isListenerRegistered) return true;

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      final requested = await requestPermission();
      if (!requested) return false;
    }

    try {
      _instance.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          final userWallets = walletRepository.getWallets();
          final tx = await processIncomingSms(
            message: message,
            transactionRepository: transactionRepository,
            userWallets: userWallets,
            notificationService: notificationService,
            customMappings: customMappings,
            showNotification: true,
          );
          if (tx != null && onTransactionReceived != null) {
            onTransactionReceived(tx);
          }
        },
        onBackgroundMessage: backgroundSmsHandler,
        listenInBackground: true,
      );
      _isListenerRegistered = true;
      return true;
    } catch (_) {
      return false;
    }
  }
}
