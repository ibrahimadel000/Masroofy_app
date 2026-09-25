import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:mizaan/core/constants/app_constants.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';

class SmsCandidateItem {
  final ParsedSmsData data;
  String? targetWalletId;
  bool isSelected;

  SmsCandidateItem({
    required this.data,
    this.targetWalletId,
    this.isSelected = true,
  });

  SmsCandidateItem copyWith({String? targetWalletId, bool? isSelected}) {
    return SmsCandidateItem(
      data: data,
      targetWalletId: targetWalletId ?? this.targetWalletId,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Top-level background message handler for telephony
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SmsService.processBackgroundIncomingSms(message);
}

class SmsService {
  final Telephony? telephony;
  static bool _isListenerRegistered = false;

  const SmsService({this.telephony});

  Telephony get _instance => telephony ?? Telephony.instance;

  /// SMS automation is opt-in. A missing preference must never look enabled.
  static bool isAutoImportEnabled(
    SharedPreferences prefs, {
    required String uid,
  }) {
    final userKey = '${uid}_smsAutoImportEnabled';
    if (prefs.containsKey(userKey)) {
      return prefs.getBool(userKey) ?? false;
    }
    if (uid == 'guest') {
      return prefs.getBool('smsAutoImportEnabled') ?? false;
    }
    return false;
  }

  /// Keep Flutter and the native Android receiver on the same explicit value.
  static Future<void> setAutoImportEnabled(
    SharedPreferences prefs, {
    required String uid,
    required bool value,
  }) async {
    if (uid.isNotEmpty) {
      await prefs.setString('current_user_id', uid);
      await prefs.setBool('${uid}_smsAutoImportEnabled', value);
    }
    // Native Android reads this alias if the active-user key is not available
    // during a cold-start broadcast. Keep it equal to the active user's choice.
    await prefs.setBool('smsAutoImportEnabled', value);
  }

  /// Check if SMS permissions (RECEIVE_SMS & READ_SMS) are granted on Android
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await Permission.sms.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request SMS permissions from user (triggers system runtime prompt)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        final bool? result = await _instance.requestPhoneAndSmsPermissions;
        return result ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Universal smart wallet matching
  /// Matches only by explicit ID, type, name, or sender mapping; otherwise returns null.
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
    final byType = userWallets
        .where((w) => w.type.toLowerCase().trim() == cleanType)
        .toList();
    if (byType.isNotEmpty) return byType.first;

    // 3. Match wallet name with walletType or template details
    final byName = userWallets.where((w) {
      final name = w.name.toLowerCase().trim();
      if (name.contains(cleanType) || cleanType.contains(name)) return true;
      if (template != null) {
        final tmplName = template.walletNameAr.toLowerCase().trim();
        if (name.contains(tmplName) || tmplName.contains(name)) return true;
        for (final id in template.senderIds) {
          if (name.contains(id.toLowerCase()) ||
              id.toLowerCase().contains(name)) {
            return true;
          }
        }
      }
      return false;
    }).toList();
    if (byName.isNotEmpty) return byName.first;

    // Never guess a destination for financial data.
    return null;
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
      final List<SmsMessage> messages = await _instance
          .getInboxSms(
            columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
            sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
          )
          .timeout(const Duration(seconds: 15));

      // CRITICAL FIX: Sort descending by date in Dart to overcome Android ContentResolver sorting bugs
      messages.sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));

      final candidates = messages.take(maxCount);

      for (final msg in candidates) {
        final address = msg.address ?? '';
        final body = msg.body ?? '';
        final date = msg.date != null
            ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
            : DateTime.now();

        // 1. Strict Privacy Filter: Skip personal / unregistered senders
        final template = SmsSenderRegistry.findTemplate(
          address,
          customMappings,
          body,
        );
        if (template == null) continue;

        // 2. Parse transaction details
        final parsed = SmsSenderRegistry.parseMessage(
          sender: address,
          body: body,
          date: date,
          customMappings: customMappings,
        );
        if (parsed == null) continue;

        // 3. Auto-match with user's wallets dynamically
        final matchedWallet = findMatchingWallet(
          userWallets: userWallets,
          walletType: parsed.walletType,
          template: template,
        );
        final matchedWalletId = matchedWallet?.id;

        // 4. Deduplication check: Skip if already imported
        if (transactionRepository.isDuplicateSms(
          smsKey: parsed.smsKey,
          referenceNumber: parsed.referenceNumber,
          rawSmsBody: parsed.rawBody,
          walletId: matchedWalletId ?? '',
          amount: parsed.amount,
          type: parsed.type,
          date: parsed.date,
        )) {
          continue;
        }

        results.add(
          SmsCandidateItem(
            data: parsed,
            targetWalletId: matchedWalletId,
            isSelected: matchedWalletId != null,
          ),
        );
      }
    } catch (_) {
      rethrow;
    }

    return results;
  }

  static final Set<String> _inFlightKeys = {};

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

      final template = SmsSenderRegistry.findTemplate(
        sender,
        customMappings,
        body,
      );
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

      if (_inFlightKeys.contains(parsed.smsKey)) return null;
      _inFlightKeys.add(parsed.smsKey);
      Future.delayed(
        const Duration(seconds: 5),
        () => _inFlightKeys.remove(parsed.smsKey),
      );

      final wRepo = walletRepository ?? WalletRepository();
      final currentWallets = wRepo.getWallets().isNotEmpty
          ? wRepo.getWallets()
          : userWallets;
      if (currentWallets.isEmpty) return null;

      final matchedWallet = findMatchingWallet(
        userWallets: currentWallets,
        walletType: parsed.walletType,
        template: template,
      );
      if (matchedWallet == null) return null;

      final matchedWalletId = matchedWallet.id;

      if (transactionRepository.isDuplicateSms(
        smsKey: parsed.smsKey,
        referenceNumber: parsed.referenceNumber,
        rawSmsBody: parsed.rawBody,
        walletId: matchedWalletId,
        amount: parsed.amount,
        type: parsed.type,
        date: parsed.date,
      )) {
        return null;
      }

      final walletName = matchedWallet.name;
      final currencyCode = matchedWallet.currencyCode;

      final prefs = await SharedPreferences.getInstance();
      final uid = DatabaseService.currentUserId ?? 'guest';
      final autoImport = SmsService.isAutoImportEnabled(prefs, uid: uid);

      TransactionModel? tx;

      if (autoImport) {
        if (parsed.isBalanceOnly) {
          // Pure balance statement / inquiry: save as adjustment transaction (0.0) to anchor statement history
          tx = TransactionModel(
            id: 'sms_${parsed.smsKey}',
            walletId: matchedWalletId,
            type: 'adjustment',
            amount: 0.0,
            category: 'كشف حساب',
            note: parsed.rawBody,
            date: parsed.date,
            source: 'sms',
            smsKey: parsed.smsKey,
            createdAt: DateTime.now(),
            rawSmsBody: parsed.rawBody,
            rawSmsSender: parsed.rawSender,
          );
          await transactionRepository.saveTransaction(tx);
          await alignWalletToStatementBalance(
            data: parsed,
            walletId: matchedWalletId,
            transactionRepository: transactionRepository,
            walletRepository: wRepo,
          );
        } else {
          // Normal transaction (deposit / expense / purchase)
          tx = TransactionModel(
            id: 'sms_${parsed.smsKey}',
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

          // Apply the balance carried by this exact SMS directly. Re-parsing
          // transaction history can miss wallet-specific balance abbreviations.
          if (parsed.balance != null) {
            await alignWalletToStatementBalance(
              data: parsed,
              walletId: matchedWalletId,
              transactionRepository: transactionRepository,
              walletRepository: wRepo,
            );
          }
        }
      }

      if (showNotification) {
        final notifEnabled =
            prefs.getBool('${uid}_smsNotificationsEnabled') ??
            prefs.getBool('smsNotificationsEnabled') ??
            true;

        if (notifEnabled) {
          final freshWallet =
              wRepo.getWalletById(matchedWalletId) ?? matchedWallet;
          final currentTxs = transactionRepository.getTransactionsByWallet(
            matchedWalletId,
          );
          final currentBal = BalanceCalculator.calculateWalletBalance(
            openingBalance: freshWallet.openingBalance,
            transactions: currentTxs,
          );

          await sendTransactionNotification(
            notificationService: notificationService,
            data: parsed,
            walletName: walletName,
            currencyCode: currencyCode,
            currentWalletBalance: currentBal,
          );
        }
      }

      return tx;
    } catch (_) {
      return null;
    }
  }

  static const String pendingSmsQueueKey =
      'mizaan_pending_background_sms_queue_v1';
  static const String pendingRawSmsKey = 'mizaan_pending_raw_sms_v1';

  /// Enqueue an incoming background SMS into SharedPreferences queue for cross-isolate safety
  static Future<void> enqueuePendingSms({
    required String sender,
    required String body,
    required int timestamp,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(pendingSmsQueueKey) ?? [];
      final itemJson = jsonEncode({
        'sender': sender,
        'body': body,
        'date': timestamp,
      });
      if (!list.contains(itemJson)) {
        list.add(itemJson);
        await prefs.setStringList(pendingSmsQueueKey, list);
      }
    } catch (_) {}
  }

  /// Drain both the native Kotlin SMS queue and the background Dart queue safely
  static Future<int> flushPendingBackgroundSms({
    TransactionRepository? transactionRepository,
    WalletRepository? walletRepository,
    NotificationService? notificationService,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Ensure active user is accurately resolved
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null &&
            (DatabaseService.currentUserId == null ||
                DatabaseService.currentUserId == 'guest')) {
          await DatabaseService.switchUser(authUser.uid);
        }
      } catch (_) {}

      final uid = DatabaseService.currentUserId ?? 'guest';
      final autoImport = SmsService.isAutoImportEnabled(prefs, uid: uid);

      if (!autoImport) {
        await prefs.remove(pendingRawSmsKey);
        await prefs.remove(pendingSmsQueueKey);
        return 0;
      }

      // 1. Gather messages from native Kotlin receiver queue
      final List<Map<String, dynamic>> rawNativeList = [];
      final rawNativeJson = prefs.getString(pendingRawSmsKey);
      if (rawNativeJson != null &&
          rawNativeJson.isNotEmpty &&
          rawNativeJson != '[]') {
        try {
          final decoded = jsonDecode(rawNativeJson);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) {
                rawNativeList.add(Map<String, dynamic>.from(item));
              }
            }
          }
        } catch (_) {}
      }

      // 2. Gather messages from Dart background queue
      final List<Map<String, dynamic>> rawDartList = [];
      final list = prefs.getStringList(pendingSmsQueueKey);
      if (list != null && list.isNotEmpty) {
        for (final rawJson in list) {
          try {
            final decoded = jsonDecode(rawJson);
            if (decoded is Map) {
              rawDartList.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        }
      }

      if (rawNativeList.isEmpty && rawDartList.isEmpty) return 0;

      final txRepo = transactionRepository ?? TransactionRepository();
      final walletRepo = walletRepository ?? WalletRepository();
      final userWallets = walletRepo.getWallets();

      // CRITICAL: If user wallets are not loaded yet (e.g. Hive box opening on initial frame),
      // DO NOT delete the pending queue! Leave it untouched for the next flush cycle.
      if (userWallets.isEmpty) return 0;

      int flushedCount = 0;
      final Set<int> handledNativeIndices = {};
      final Set<int> handledDartIndices = {};

      // Process native Kotlin messages
      for (int i = 0; i < rawNativeList.length; i++) {
        final map = rawNativeList[i];
        final bool success = await _processPendingMessage(
          map: map,
          userWallets: userWallets,
          txRepo: txRepo,
          walletRepo: walletRepo,
        );
        if (success) {
          handledNativeIndices.add(i);
          flushedCount++;
        } else {
          // Check if it's already a duplicate or corrupt so we don't loop forever
          if (_isCorruptOrDuplicate(
            map: map,
            txRepo: txRepo,
            userWallets: userWallets,
          )) {
            handledNativeIndices.add(i);
          }
        }
      }

      // Process Dart queue messages
      for (int i = 0; i < rawDartList.length; i++) {
        final map = rawDartList[i];
        final bool success = await _processPendingMessage(
          map: map,
          userWallets: userWallets,
          txRepo: txRepo,
          walletRepo: walletRepo,
        );
        if (success) {
          handledDartIndices.add(i);
          flushedCount++;
        } else {
          if (_isCorruptOrDuplicate(
            map: map,
            txRepo: txRepo,
            userWallets: userWallets,
          )) {
            handledDartIndices.add(i);
          }
        }
      }

      // Update native queue in SharedPreferences
      final remainingNative = [
        for (int i = 0; i < rawNativeList.length; i++)
          if (!handledNativeIndices.contains(i)) rawNativeList[i],
      ];
      if (remainingNative.isEmpty) {
        await prefs.remove(pendingRawSmsKey);
      } else {
        await prefs.setString(pendingRawSmsKey, jsonEncode(remainingNative));
      }

      // Update Dart queue in SharedPreferences
      final remainingDart = [
        for (int i = 0; i < rawDartList.length; i++)
          if (!handledDartIndices.contains(i)) jsonEncode(rawDartList[i]),
      ];
      if (remainingDart.isEmpty) {
        await prefs.remove(pendingSmsQueueKey);
      } else {
        await prefs.setStringList(pendingSmsQueueKey, remainingDart);
      }

      // Repair any historical SMS transactions that were misclassified or saved with 0.0 amount
      final repairedCount = await txRepo.repairMisclassifiedSmsTransactions();

      if (flushedCount > 0 || repairedCount > 0) {
        await const SmsService().reconcileWalletsWithLatestSms(
          transactionRepository: txRepo,
          walletRepository: walletRepo,
        );
      }

      return flushedCount + repairedCount;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> _processPendingMessage({
    required Map<String, dynamic> map,
    required List<Wallet> userWallets,
    required TransactionRepository txRepo,
    required WalletRepository walletRepo,
  }) async {
    try {
      final sender = map['sender'] as String? ?? '';
      final body = map['body'] as String? ?? '';
      final dateMs =
          map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final date = DateTime.fromMillisecondsSinceEpoch(dateMs);

      if (sender.isEmpty || body.isEmpty) return false;

      final template = SmsSenderRegistry.findTemplate(sender, null, body);
      if (template == null) return false;

      final parsed = SmsSenderRegistry.parseMessage(
        sender: sender,
        body: body,
        date: date,
      );
      if (parsed == null) return false;

      final matchedWallet = findMatchingWallet(
        userWallets: userWallets,
        walletType: parsed.walletType,
        template: template,
      );
      if (matchedWallet == null) return false;

      if (txRepo.isDuplicateSms(
        smsKey: parsed.smsKey,
        referenceNumber: parsed.referenceNumber,
        rawSmsBody: parsed.rawBody,
        walletId: matchedWallet.id,
        amount: parsed.amount,
        type: parsed.type,
        date: parsed.date,
      )) {
        return false;
      }

      final tx = TransactionModel(
        id: 'sms_${parsed.smsKey}',
        walletId: matchedWallet.id,
        type: parsed.type,
        amount: parsed.amount,
        category: parsed.isBalanceOnly ? 'كشف حساب' : parsed.category,
        note: parsed.rawBody,
        date: parsed.date,
        source: 'sms',
        smsKey: parsed.smsKey,
        createdAt: DateTime.now(),
        rawSmsBody: parsed.rawBody,
        rawSmsSender: parsed.rawSender,
      );
      await txRepo.saveTransaction(tx);
      if (parsed.balance != null) {
        await const SmsService().alignWalletToStatementBalance(
          data: parsed,
          walletId: matchedWallet.id,
          transactionRepository: txRepo,
          walletRepository: walletRepo,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isCorruptOrDuplicate({
    required Map<String, dynamic> map,
    required TransactionRepository txRepo,
    required List<Wallet> userWallets,
  }) {
    final sender = map['sender'] as String? ?? '';
    final body = map['body'] as String? ?? '';
    if (sender.isEmpty || body.isEmpty) return true;
    if (SmsSenderRegistry.isBlockedSender(sender)) return true;

    final dateMs = map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final date = DateTime.fromMillisecondsSinceEpoch(dateMs);

    final template = SmsSenderRegistry.findTemplate(sender, null, body);
    if (template == null) return false;

    final parsed = SmsSenderRegistry.parseMessage(
      sender: sender,
      body: body,
      date: date,
    );
    if (parsed == null) return false;

    final matchedWallet = findMatchingWallet(
      userWallets: userWallets,
      walletType: parsed.walletType,
      template: template,
    );
    if (matchedWallet == null) return false;

    return txRepo.isDuplicateSms(
      smsKey: parsed.smsKey,
      referenceNumber: parsed.referenceNumber,
      rawSmsBody: parsed.rawBody,
      walletId: matchedWallet.id,
      amount: parsed.amount,
      type: parsed.type,
      date: parsed.date,
    );
  }

  /// Queue background SMS for processing on the main isolate.
  /// Native Android owns the single user notification; Hive is never opened here.
  static Future<TransactionModel?> processBackgroundIncomingSms(
    SmsMessage message,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final sender = message.address ?? '';
      final body = message.body ?? '';
      if (sender.isEmpty || body.isEmpty) return null;
      if (SmsSenderRegistry.findTemplate(sender, null, body) == null) {
        return null;
      }
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_user_id') ?? 'guest';
      if (!SmsService.isAutoImportEnabled(prefs, uid: uid)) return null;
      await enqueuePendingSms(
        sender: sender,
        body: body,
        timestamp: message.date ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
    return null;
  }

  /// Aligns the calculated wallet total to the authoritative balance carried by
  /// one parsed SMS, while preserving transactions that occurred after it.
  Future<bool> alignWalletToStatementBalance({
    required ParsedSmsData data,
    required String walletId,
    required TransactionRepository transactionRepository,
    required WalletRepository walletRepository,
  }) async {
    final statementBalance = data.balance;
    if (statementBalance == null) return false;

    final wallet = walletRepository.getWalletById(walletId);
    if (wallet == null) return false;
    final txs = transactionRepository.getTransactionsByWallet(walletId);
    final currentBalance = BalanceCalculator.calculateWalletBalance(
      openingBalance: wallet.openingBalance,
      transactions: txs,
    );

    double newerDelta = 0.0;
    for (final tx in txs) {
      if (!tx.date.isAfter(data.date)) continue;
      if (tx.type == 'income') {
        newerDelta += tx.amount;
      } else if (tx.type == 'expense') {
        newerDelta -= tx.amount;
      } else if (tx.type == 'adjustment') {
        newerDelta += tx.amount;
      }
    }

    final expectedCurrentBalance = statementBalance + newerDelta;
    final correction = expectedCurrentBalance - currentBalance;
    if (correction.abs() < 0.01) return false;

    await walletRepository.saveWallet(
      wallet.copyWith(openingBalance: wallet.openingBalance + correction),
    );
    return true;
  }

  /// Reconcile wallets with the latest verified SMS balance found in their transaction history
  Future<int> reconcileWalletsWithLatestSms({
    required TransactionRepository transactionRepository,
    required WalletRepository walletRepository,
  }) async {
    final wallets = walletRepository.getWallets();
    int reconciledCount = 0;

    for (final wallet in wallets) {
      final txs = transactionRepository.getTransactionsByWallet(wallet.id);
      if (txs.isEmpty) continue;

      // Find the newest SMS transaction that contains an authoritative bank balance
      double? latestBalance;
      int statementIndex = -1;

      for (int i = 0; i < txs.length; i++) {
        final tx = txs[i];
        if (tx.rawSmsBody != null) {
          final parsed = SmsSenderRegistry.parseMessage(
            sender: tx.rawSmsSender ?? '',
            body: tx.rawSmsBody!,
            date: tx.date,
          );
          if (parsed != null && parsed.balance != null) {
            latestBalance = parsed.balance;
            statementIndex = i;
            break; // txs is already sorted by date descending, so first match is the latest statement!
          }
        }
      }

      if (latestBalance != null && statementIndex != -1) {
        // txs is sorted by date descending:
        // Indices 0 to statementIndex - 1 are transactions that occurred AFTER the statement.
        // Indices statementIndex to txs.length - 1 are transactions that occurred AT OR BEFORE the statement.
        // The bank balance in latestBalance is the ground-truth balance immediately after statementTxs.
        // Therefore, opening balance anchor is: latestBalance - txSumUpToStatement.
        final statementTxs = txs.sublist(statementIndex);
        double txSumUpToStatement = 0.0;
        for (final t in statementTxs) {
          if (t.type == 'income') {
            txSumUpToStatement += t.amount;
          } else if (t.type == 'expense') {
            txSumUpToStatement -= t.amount;
          } else if (t.type == 'adjustment') {
            txSumUpToStatement += t.amount;
          }
        }

        final targetOpening = latestBalance - txSumUpToStatement;
        if ((targetOpening - wallet.openingBalance).abs() >= 0.01) {
          final updated = wallet.copyWith(openingBalance: targetOpening);
          await walletRepository.saveWallet(updated);
          reconciledCount++;
        }
      }
    }
    return reconciledCount;
  }

  /// Send instant local notification for an imported transaction
  static Future<void> sendTransactionNotification({
    required NotificationService notificationService,
    required ParsedSmsData data,
    required String walletName,
    required String currencyCode,
    double? currentWalletBalance,
  }) async {
    try {
      if (data.isBalanceOnly) {
        final balText = AppConstants.formatCurrency(
          data.balance ?? currentWalletBalance ?? 0.0,
          currencyCode,
        );
        await notificationService.showTransactionAlert(
          title: '🔄 تحديث الرصيد - $walletName',
          body: 'تم تحديث رصيد $walletName الفعلي إلى $balText',
        );
        return;
      }

      final formattedAmount = AppConstants.formatCurrency(
        data.amount,
        currencyCode,
      );
      final isExpense = data.type == 'expense';
      final isPurchase =
          isExpense &&
          (data.category == 'بقالة' ||
              data.category == 'مشتريات' ||
              data.rawBody.contains('شراء') ||
              data.rawBody.contains('مشتريات'));

      final double? effectiveBal = data.balance ?? currentWalletBalance;
      final balanceText = effectiveBal != null
          ? ' (الرصيد المتبقي: ${AppConstants.formatCurrency(effectiveBal, currencyCode)})'
          : '';

      final String title;
      final String notifBody;
      if (isExpense) {
        title = isPurchase
            ? '🛍️ عملية شراء جديدة - $walletName'
            : '💸 عملية خصم جديدة - $walletName';
        notifBody =
            'تم تسجيل عملية ${isPurchase ? "شراء" : "خصم"} بمبلغ $formattedAmount من $walletName$balanceText';
      } else {
        title = '💰 إيداع جديد - $walletName';
        notifBody =
            'تم تسجيل إيداع بمبلغ $formattedAmount في $walletName$balanceText';
      }

      await notificationService.showTransactionAlert(
        title: title,
        body: notifBody,
      );
    } catch (_) {}
  }

  /// Register telephony listener for incoming SMS (both foreground and background)
  Future<bool> startIncomingSmsListener({
    required TransactionRepository transactionRepository,
    required WalletRepository walletRepository,
    required NotificationService notificationService,
    Function(TransactionModel tx)? onTransactionReceived,
    Map<String, String>? customMappings,
    bool requestIfNotGranted = false,
  }) async {
    if (!Platform.isAndroid) return false;
    if (_isListenerRegistered) return true;

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      if (!requestIfNotGranted) return false;
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
            walletRepository: walletRepository,
            customMappings: customMappings,
            // Native receiver owns notifications; avoid duplicate alerts.
            showNotification: false,
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
