import 'dart:io';
import 'package:telephony/telephony.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';

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

class SmsService {
  final Telephony? telephony;

  const SmsService({this.telephony});

  Telephony get _instance => telephony ?? Telephony.instance;

  /// Check if SMS read permission is granted (Android only)
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted = await _instance.isSmsCapable;
      if (granted != true) return false;
      // telephony provides requestPhoneAndSmsPermissions or check
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
}
