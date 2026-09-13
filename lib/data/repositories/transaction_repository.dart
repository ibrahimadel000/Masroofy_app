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

  Box<TransactionModel> get _box => _customBox ?? DatabaseService.transactionsBox;
  Box<bool> get _keysBox => _customKeysBox ?? DatabaseService.smsKeysBox;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  List<TransactionModel> getTransactions() {
    final list = _box.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Stream<List<TransactionModel>> watchTransactions() {
    return _box.watch().map((_) => getTransactions());
  }

  List<TransactionModel> getTransactionsByWallet(String walletId) {
    final list = _box.values.where((tx) => tx.walletId == walletId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  bool hasSmsKey(String smsKey) {
    return _keysBox.containsKey(smsKey);
  }

  Future<void> saveSmsKey(String smsKey) async {
    await _keysBox.put(smsKey, true);
  }

  Future<void> saveTransaction(TransactionModel tx) async {
    // 1. Local write to Hive (offline-first source of truth)
    await _box.put(tx.id, tx);

    if (tx.smsKey != null) {
      await saveSmsKey(tx.smsKey!);
    }

    // 2. Attempt sync to Firestore if online/logged in
    final uid = _currentUserId;
    if (uid != null) {
      try {
        await _firestore
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
    if (uid != null) {
      try {
        await _firestore
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
    if (uid == null) return;

    try {
      final snapshot = await _firestore
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
