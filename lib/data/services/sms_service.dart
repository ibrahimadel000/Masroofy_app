import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
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

        // 4. Auto-match with user's wallets by type
        String? matchedWalletId;
        final matchingWallets = userWallets.where((w) => w.type == parsed.walletType).toList();
        if (matchingWallets.isNotEmpty) {
          matchedWalletId = matchingWallets.first.id;
        } else if (userWallets.isNotEmpty) {
          // Fallback to first wallet if no exact type match
          matchedWalletId = userWallets.first.id;
        }

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

      String? matchedWalletId;
      String walletName = template.walletNameAr;
      String currencyCode = 'YER';
      final matchingWallets = userWallets.where((w) => w.type == parsed.walletType).toList();
      if (matchingWallets.isNotEmpty) {
        matchedWalletId = matchingWallets.first.id;
        walletName = matchingWallets.first.name;
        currencyCode = matchingWallets.first.currencyCode;
      } else {
        matchedWalletId = userWallets.first.id;
        walletName = userWallets.first.name;
        currencyCode = userWallets.first.currencyCode;
      }

      final tx = TransactionModel(
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

      String? matchedWalletId;
      String walletName = template.walletNameAr;
      String currencyCode = 'YER';
      final matchingWallets = userWallets.where((w) => w.type == parsed.walletType).toList();
      if (matchingWallets.isNotEmpty) {
        matchedWalletId = matchingWallets.first.id;
        walletName = matchingWallets.first.name;
        currencyCode = matchingWallets.first.currencyCode;
      } else {
        matchedWalletId = userWallets.first.id;
        walletName = userWallets.first.name;
        currencyCode = userWallets.first.currencyCode;
      }

      final tx = TransactionModel(
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
