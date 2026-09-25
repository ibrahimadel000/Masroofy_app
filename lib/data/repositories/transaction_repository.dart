import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/services/database_service.dart';

class TransactionRepository {
  static final Set<String> _inFlightSmsSaves = {};

  final Box<TransactionModel>? _customBox;
  final Box<bool>? _customKeysBox;
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  TransactionRepository({
    Box<TransactionModel>? box,
    Box<bool>? keysBox,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _customBox = box,
       _customKeysBox = keysBox,
       _customFirestore = firestore,
       _customAuth = auth;

  Box<TransactionModel>? get _safeBox {
    try {
      return _customBox ??
          (DatabaseService.isInitialized
              ? DatabaseService.transactionsBox
              : null);
    } catch (_) {
      return null;
    }
  }

  Box<bool>? get _safeKeysBox {
    try {
      return _customKeysBox ??
          (DatabaseService.isInitialized ? DatabaseService.smsKeysBox : null);
    } catch (_) {
      return null;
    }
  }

  Box<TransactionModel> get _box => _safeBox ?? DatabaseService.transactionsBox;

  FirebaseFirestore? get _firestore {
    try {
      return _customFirestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return _customAuth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUserId {
    try {
      return _auth?.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Normalize any text for robust semantic comparison (removes whitespace, punctuation, normalizes digits)
  static String normalizeBodyForComparison(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    return SmsSenderRegistry.normalizeDigits(
      text,
    ).toLowerCase().replaceAll(RegExp(r'[\s\r\n\t,.:\-_/\\|]+'), '').trim();
  }

  /// Deduplicate a list of transactions in memory ensuring each real operation appears only once
  static List<TransactionModel> deduplicateList(
    List<TransactionModel> rawList,
  ) {
    if (rawList.length <= 1) return rawList;

    final List<TransactionModel> uniqueList = [];
    final Set<String> seenIds = {};
    final Set<String> seenKeys = {};

    for (final tx in rawList) {
      if (seenIds.contains(tx.id)) continue;

      bool isDup = false;

      // 1. Match by smsKey. Reference-like fields are not used alone:
      // some providers repeat an account/subscriber number across deposits.
      if (tx.smsKey != null && tx.smsKey!.isNotEmpty) {
        if (seenKeys.contains(tx.smsKey)) {
          isDup = true;
        } else {
          seenKeys.add(tx.smsKey!);
        }
      }

      // 3. Match by semantic SMS content or matching manual notes
      if (!isDup) {
        final normText = normalizeBodyForComparison(tx.rawSmsBody ?? tx.note);

        for (final accepted in uniqueList) {
          if (accepted.walletId == tx.walletId &&
              accepted.type == tx.type &&
              (accepted.amount - tx.amount).abs() < 0.01) {
            final isSms =
                tx.source == 'sms' ||
                accepted.source == 'sms' ||
                tx.rawSmsBody != null ||
                accepted.rawSmsBody != null;

            if (isSms) {
              if (_isDuplicateSmsRecord(incoming: tx, existing: accepted)) {
                isDup = true;
                break;
              }
            } else {
              // Purely manual: only consider duplicate if within 5 minutes and same note
              final diff = accepted.date.difference(tx.date).abs();
              if (normText.isNotEmpty &&
                  diff.inMinutes <= 5 &&
                  accepted.note == tx.note) {
                isDup = true;
                break;
              }
            }
          }
        }
      }

      if (!isDup) {
        seenIds.add(tx.id);
        uniqueList.add(tx);
      }
    }

    return uniqueList;
  }

  /// Returns true only when two SMS records represent the same delivery or
  /// the same identifiable purchase.
  static bool _isDuplicateSmsRecord({
    required TransactionModel incoming,
    required TransactionModel existing,
  }) {
    if (incoming.walletId != existing.walletId ||
        incoming.type != existing.type ||
        (incoming.amount - existing.amount).abs() >= 0.01) {
      return false;
    }

    final incomingBody = incoming.rawSmsBody ?? incoming.note;
    final existingBody = existing.rawSmsBody ?? existing.note;
    final incomingNorm = normalizeBodyForComparison(incomingBody);
    final existingNorm = normalizeBodyForComparison(existingBody);
    if (incomingNorm.isEmpty || incomingNorm != existingNorm) return false;

    final timestampDiff = incoming.date.difference(existing.date).abs();
    if (timestampDiff.inSeconds <= 10) return true;

    final incomingReference = incoming.referenceNumber;
    final existingReference = existing.referenceNumber;
    final isPurchase = _isPurchaseText(incomingBody);

    if (isPurchase &&
        incomingReference != null &&
        incomingReference == existingReference) {
      return true;
    }

    if (incomingReference == null &&
        existingReference == null &&
        _isSameCalendarDay(incoming.date, existing.date)) {
      return true;
    }

    return false;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isPurchaseText(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final normalized = text.toLowerCase();
    const purchaseTerms = [
      'شراء',
      'مشتريات',
      'حاسب',
      'نقاط البيع',
      'سداد',
      'دفع',
      'purchase',
      'payment',
      'pos',
    ];
    return purchaseTerms.any(normalized.contains);
  }

  static String _smsSaveFingerprint(TransactionModel tx) {
    final sender = (tx.rawSmsSender ?? '').trim().toLowerCase();
    final body = normalizeBodyForComparison(tx.rawSmsBody ?? tx.note);
    return '$sender|${tx.walletId}|${tx.type}|${tx.amount}|$body';
  }

  List<TransactionModel> getTransactions() {
    try {
      final box = _safeBox;
      if (box == null) return [];
      final list = box.values.toList();
      list.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return deduplicateList(list);
    } catch (_) {
      return [];
    }
  }

  Stream<List<TransactionModel>> watchTransactions() {
    try {
      final box = _safeBox;
      if (box == null) return Stream.value([]);
      return box.watch().map((_) => getTransactions());
    } catch (_) {
      return Stream.value([]);
    }
  }

  List<TransactionModel> getTransactionsByWallet(String walletId) {
    try {
      final box = _safeBox;
      if (box == null) return [];
      final list = box.values.where((tx) => tx.walletId == walletId).toList();
      list.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return deduplicateList(list);
    } catch (_) {
      return [];
    }
  }

  bool hasSmsKey(String smsKey) {
    try {
      final keysBox = _safeKeysBox;
      if (keysBox != null && keysBox.containsKey(smsKey)) return true;
      final box = _safeBox;
      if (box != null) {
        for (final tx in box.values) {
          if (tx.smsKey == smsKey) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSmsKey(String smsKey) async {
    try {
      final keysBox = _safeKeysBox;
      if (keysBox != null) {
        await keysBox.put(smsKey, true);
      }
    } catch (_) {}
  }

  /// Comprehensive multi-layer check to ensure no SMS transaction is ever duplicated
  bool isDuplicateSms({
    required String smsKey,
    String? referenceNumber,
    String? rawSmsBody,
    required String walletId,
    required double amount,
    required String type,
    required DateTime date,
  }) {
    try {
      // 1. Direct smsKey check
      if (hasSmsKey(smsKey)) return true;

      final box = _safeBox;
      if (box == null) return false;

      final allTxs = box.values;

      final incoming = TransactionModel(
        id: '__incoming_sms_probe__',
        walletId: walletId,
        type: type,
        amount: amount,
        category: 'sms',
        note: rawSmsBody,
        date: date,
        source: 'sms',
        smsKey: smsKey,
        createdAt: date,
        rawSmsBody: rawSmsBody,
      );

      for (final tx in allTxs) {
        if (_isDuplicateSmsRecord(incoming: incoming, existing: tx)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Automatically clean up existing duplicate transactions in Hive and Firestore
  Future<int> cleanDuplicateTransactions() async {
    try {
      final box = _safeBox;
      if (box == null) return 0;
      final all = box.values.toList();
      if (all.length <= 1) return 0;

      // Sort by createdAt so we keep the first saved transaction
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final unique = deduplicateList(all);
      final uniqueIds = unique.map((t) => t.id).toSet();

      final toDelete = all.where((t) => !uniqueIds.contains(t.id)).toList();
      if (toDelete.isEmpty) return 0;

      int removedCount = 0;
      for (final tx in toDelete) {
        await deleteTransaction(tx.id);
        removedCount++;
      }
      return removedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Automatically repair existing transactions in Hive that were saved as 0.0 adjustments or misclassified
  Future<int> repairMisclassifiedSmsTransactions() async {
    try {
      final box = _safeBox;
      if (box == null) return 0;
      final all = box.values.toList();
      int repairedCount = 0;

      for (final tx in all) {
        final rawBody = tx.rawSmsBody;
        if (rawBody == null || rawBody.isEmpty) continue;
        // Target transactions that were saved with 0.0 amount or adjustment type despite having a real transaction body
        if (tx.amount <= 0.01 || tx.type == 'adjustment') {
          final parsed = SmsSenderRegistry.parseMessage(
            sender: tx.rawSmsSender ?? '',
            body: rawBody,
            date: tx.date,
          );
          if (parsed != null && !parsed.isBalanceOnly && parsed.amount > 0) {
            final updated = tx.copyWith(
              type: parsed.type,
              amount: parsed.amount,
              category: parsed.category,
            );
            await saveTransaction(updated);
            repairedCount++;
          }
        }
      }
      return repairedCount;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveTransaction(TransactionModel tx) async {
    String? inFlightFingerprint;
    if (tx.source == 'sms') {
      inFlightFingerprint = _smsSaveFingerprint(tx);
      if (!_inFlightSmsSaves.add(inFlightFingerprint)) return;
    }

    try {
      final existingWithSameId = _safeBox?.get(tx.id);
      if (existingWithSameId == null &&
          tx.source == 'sms' &&
          isDuplicateSms(
            smsKey: tx.smsKey ?? '',
            referenceNumber: tx.referenceNumber,
            rawSmsBody: tx.rawSmsBody ?? tx.note,
            walletId: tx.walletId,
            amount: tx.amount,
            type: tx.type,
            date: tx.date,
          )) {
        return;
      }

      // 1. Local write to Hive (offline-first source of truth)
      await _box.put(tx.id, tx);

      if (tx.smsKey != null) {
        await saveSmsKey(tx.smsKey!);
      }

      // 2. Attempt sync to Firestore in background (fire-and-forget so offline execution never hangs)
      final uid = _currentUserId;
      final fs = _firestore;
      if (uid != null && fs != null) {
        unawaited(
          fs
              .collection('users')
              .doc(uid)
              .collection('transactions')
              .doc(tx.id)
              .set(tx.toCloudMap(), SetOptions(merge: true))
              .timeout(const Duration(seconds: 3))
              .catchError((_) {}),
        );
      }
    } finally {
      if (inFlightFingerprint != null) {
        _inFlightSmsSaves.remove(inFlightFingerprint);
      }
    }
  }

  Future<int> purgeBlockedSenderTransactions() async {
    final box = _safeBox;
    if (box == null) return 0;

    final blocked = box.values
        .where((tx) => SmsSenderRegistry.isBlockedSender(tx.rawSmsSender ?? ''))
        .map((tx) => tx.id)
        .toList(growable: false);
    for (final id in blocked) {
      await deleteTransaction(id);
    }
    return blocked.length;
  }

  Future<int> deleteTransactionsForWallet(String walletId) async {
    final ids = _box.values
        .where((tx) => tx.walletId == walletId)
        .map((tx) => tx.id)
        .toList(growable: false);
    for (final id in ids) {
      await deleteTransaction(id);
    }
    return ids.length;
  }

  Future<void> deleteTransaction(String id) async {
    // 1. Delete from Hive
    await _box.delete(id);

    // 2. Delete from Firestore in background (fire-and-forget)
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      unawaited(
        fs
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 3))
            .catchError((_) {}),
      );
    }
  }

  Future<void> syncFromFirestore() async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return;

    try {
      final snapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .get();

      for (final doc in snapshot.docs) {
        final tx = TransactionModel.fromMap(doc.data());
        // Hive is the local source of truth. Do not overwrite a local SMS
        // transaction during startup with an older/cloud-stripped copy.
        // Firestore only fills records that are not present locally.
        if (!_box.containsKey(tx.id)) {
          await _box.put(tx.id, tx);
          if (tx.smsKey != null) {
            await saveSmsKey(tx.smsKey!);
          }
        }
      }
      await cleanDuplicateTransactions();
    } catch (_) {
      // Offline fallback
    }
  }
}
