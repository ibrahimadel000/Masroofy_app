import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/services/database_service.dart';

class WalletRepository {
  final Box<Wallet>? _customBox;
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  WalletRepository({
    Box<Wallet>? box,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customBox = box,
        _customFirestore = firestore,
        _customAuth = auth;

  Box<Wallet> get _box => _customBox ?? DatabaseService.walletsBox;

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

  List<Wallet> getWallets() {
    final wallets = _box.values.toList();
    wallets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return wallets;
  }

  Stream<List<Wallet>> watchWallets() {
    return _box.watch().map((_) => getWallets());
  }

  Wallet? getWalletById(String id) {
    try {
      return _box.values.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWallet(Wallet wallet) async {
    // 1. Local Hive write first (offline-first source of truth)
    await _box.put(wallet.id, wallet);

    // 2. Attempt Firestore sync if online/logged in
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        await fs
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc(wallet.id)
            .set(wallet.toMap(), SetOptions(merge: true));
      } catch (_) {
        // Offline or network failure: Hive remains the source of truth
      }
    }
  }

  Future<void> deleteWallet(String id) async {
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
            .collection('wallets')
            .doc(id)
            .delete();
      } catch (_) {
        // Silent catch for offline mode
      }
    }
  }

  Future<void> toggleFavorite(String id) async {
    final wallet = getWalletById(id);
    if (wallet != null) {
      final updated = wallet.copyWith(isFavorite: !wallet.isFavorite);
      await saveWallet(updated);
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
          .collection('wallets')
          .get();

      for (final doc in snapshot.docs) {
        final wallet = Wallet.fromMap(doc.data());
        await _box.put(wallet.id, wallet);
      }
    } catch (_) {
      // Offline fallback
    }
  }
}
