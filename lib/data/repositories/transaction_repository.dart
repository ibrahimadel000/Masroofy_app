import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/services/database_service.dart';

class TransactionRepository {
  final Box<TransactionModel>? _customBox;
  final Box<bool>? _customKeysBox;
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  TransactionRepository({
    Box<TransactionModel>? box,
    Box<bool>? keysBox,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customBox = box,
        _customKeysBox = keysBox,
        _customFirestore = firestore,
        _customAuth = auth;

  Box<TransactionModel>? get _safeBox {
    try {
      return _customBox ?? (DatabaseService.isInitialized ? DatabaseService.transactionsBox : null);
    } catch (_) {
      return null;
    }
  }

  Box<bool>? get _safeKeysBox {
    try {
      return _customKeysBox ?? (DatabaseService.isInitialized ? DatabaseService.smsKeysBox : null);
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
    return SmsSenderRegistry.normalizeDigits(text)
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\r\n\t,.:\-_/\\|]+'), '')
        .trim();
  }

  /// Deduplicate a list of transactions in memory ensuring each real operation appears only once
  static List<TransactionModel> deduplicateList(List<TransactionModel> rawList) {
    if (rawList.length <= 1) return rawList;

    final List<TransactionModel> uniqueList = [];
    final Set<String> seenIds = {};
    final Set<String> seenRefs = {};
    final Set<String> seenKeys = {};

    for (final tx in rawList) {
      if (seenIds.contains(tx.id)) continue;

      bool isDup = false;

      // 1. Match by reference number (100% unique bank ID)
      final ref = tx.referenceNumber;
      if (ref != null && ref.isNotEmpty) {
        if (seenRefs.contains(ref)) {
          isDup = true;
        } else {
          seenRefs.add(ref);
        }
      }

      // 2. Match by smsKey
      if (!isDup && tx.smsKey != null && tx.smsKey!.isNotEmpty) {
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
            // If both have SMS/note content, compare normalized text
            if (normText.isNotEmpty) {
              final acceptedNorm = normalizeBodyForComparison(accepted.rawSmsBody ?? accepted.note);
              if (acceptedNorm.isNotEmpty && acceptedNorm == normText) {
                isDup = true;
                break;
              }
            }

            // If either is SMS and occurred on the same calendar day
            final isSms = tx.source == 'sms' ||
                accepted.source == 'sms' ||
                tx.rawSmsBody != null ||
                accepted.rawSmsBody != null;

            if (isSms) {
              final d1 = tx.date.toLocal();
              final d2 = accepted.date.toLocal();
              if (d1.year == d2.year && d1.month == d2.month && d1.day == d2.day) {
                final diff = d1.difference(d2).abs();
                if (diff.inHours <= 12) {
                  isDup = true;
                  break;
                }
              }
            } else {
              // Purely manual: only consider duplicate if within 5 minutes and same note
              final diff = accepted.date.difference(tx.date).abs();
              if (diff.inMinutes <= 5 && accepted.note == tx.note) {
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

      // 2. Reference number match (bank reference numbers are 100% unique)
      if (referenceNumber != null && referenceNumber.isNotEmpty) {
        for (final tx in allTxs) {
          if (tx.referenceNumber == referenceNumber) return true;
        }
      }

      // 3. Match by normalized SMS body / note (IDENTICAL SMS BODY)
      final normBody = normalizeBodyForComparison(rawSmsBody);

      for (final tx in allTxs) {
        if (tx.walletId == walletId &&
            tx.type == type &&
            (tx.amount - amount).abs() < 0.01) {
          if (normBody.isNotEmpty) {
            final txNorm = normalizeBodyForComparison(tx.rawSmsBody ?? tx.note);
            if (txNorm.isNotEmpty && txNorm == normBody) return true;
          }

          final d1 = date.toLocal();
          final d2 = tx.date.toLocal();
          if (d1.year == d2.year && d1.month == d2.month && d1.day == d2.day) {
            final diff = d1.difference(d2).abs();
            if (diff.inHours <= 12) return true;
          }
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

  Future<void> saveTransaction(TransactionModel tx) async {
    // 1. Local write to Hive (offline-first source of truth)
    await _box.put(tx.id, tx);

    if (tx.smsKey != null) {
      await saveSmsKey(tx.smsKey!);
    }

    // 2. Attempt sync to Firestore if online/logged in
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        await fs
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(tx.id)
            .set(tx.toMap(), SetOptions(merge: true));
      } catch (_) {
        // Offline fallback
      }
    }
  }

  Future<void> deleteTransaction(String id) async {
    // 1. Delete from Hive
    await _box.delete(id);

    // 2. Delete from Firestore if logged in
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        await fs
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(id)
            .delete();
      } catch (_) {
        // Offline fallback
      }
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
        await _box.put(tx.id, tx);
        if (tx.smsKey != null) {
          await saveSmsKey(tx.smsKey!);
        }
      }
      await cleanDuplicateTransactions();
    } catch (_) {
      // Offline fallback
    }
  }
}
