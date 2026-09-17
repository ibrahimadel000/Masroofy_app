import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  List<TransactionModel> getTransactions() {
    try {
      final box = _safeBox;
      if (box == null) return [];
      final list = box.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
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
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
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

      final cleanBody = rawSmsBody?.replaceAll(RegExp(r'\s+'), ' ').trim();

      for (final tx in allTxs) {
        if (tx.walletId == walletId &&
            tx.type == type &&
            (tx.amount - amount).abs() < 0.01) {
          // Compare date within 2 hours
          final diff = tx.date.difference(date).abs();
          if (diff.inHours <= 2) {
            if (cleanBody != null && tx.rawSmsBody != null) {
              final txClean = tx.rawSmsBody!.replaceAll(RegExp(r'\s+'), ' ').trim();
              if (txClean == cleanBody) return true;
            } else if (diff.inMinutes <= 15) {
              return true;
            }
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

      int removedCount = 0;
      final Set<String> seenRefs = {};
      final Set<String> seenKeys = {};
      final List<String> toDeleteIds = [];

    // Sort by date descending (keep the earliest or latest stable copy)
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final List<TransactionModel> kept = [];

    for (final tx in all) {
      bool isDup = false;

      // 1. Check reference number
      final ref = tx.referenceNumber;
      if (ref != null && ref.isNotEmpty) {
        if (seenRefs.contains(ref)) {
          isDup = true;
        } else {
          seenRefs.add(ref);
        }
      }

      // 2. Check smsKey
      if (!isDup && tx.smsKey != null && tx.smsKey!.isNotEmpty) {
        if (seenKeys.contains(tx.smsKey)) {
          isDup = true;
        } else {
          seenKeys.add(tx.smsKey!);
        }
      }

      // 3. Check semantic duplicate against already kept transactions
      if (!isDup) {
        final cleanBody = tx.rawSmsBody?.replaceAll(RegExp(r'\s+'), ' ').trim() ??
            tx.note?.replaceAll(RegExp(r'\s+'), ' ').trim();

        for (final k in kept) {
          if (k.walletId == tx.walletId &&
              k.type == tx.type &&
              (k.amount - tx.amount).abs() < 0.01) {
            final diff = k.date.difference(tx.date).abs();
            if (diff.inMinutes <= 30) {
              final kClean = k.rawSmsBody?.replaceAll(RegExp(r'\s+'), ' ').trim() ??
                  k.note?.replaceAll(RegExp(r'\s+'), ' ').trim();
              if (cleanBody != null && kClean != null && cleanBody == kClean) {
                isDup = true;
                break;
              } else if (diff.inMinutes <= 5) {
                isDup = true;
                break;
              }
            }
          }
        }
      }

      if (isDup) {
        toDeleteIds.add(tx.id);
      } else {
        kept.add(tx);
      }
    }

    for (final id in toDeleteIds) {
      await deleteTransaction(id);
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
    } catch (_) {
      // Offline fallback
    }
  }
}
