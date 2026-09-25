import 'dart:async';
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
  }) : _customBox = box,
       _customFirestore = firestore,
       _customAuth = auth;

  Box<Wallet>? get _safeBox {
    try {
      return _customBox ??
          (DatabaseService.isInitialized ? DatabaseService.walletsBox : null);
    } catch (_) {
      return null;
    }
  }

  Box<Wallet> get _box => _safeBox ?? DatabaseService.walletsBox;

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
    try {
      final box = _safeBox;
      if (box == null) return [];
      final wallets = box.values.toList();
      wallets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return wallets;
    } catch (_) {
      return [];
    }
  }

  Stream<List<Wallet>> watchWallets() {
    try {
      final box = _safeBox;
      if (box == null) return Stream.value([]);
      return box.watch().map((_) => getWallets());
    } catch (_) {
      return Stream.value([]);
    }
  }

  Wallet? getWalletById(String id) {
    try {
      final box = _safeBox;
      if (box == null) return null;
      return box.values.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWallet(Wallet wallet) async {
    // 1. Local Hive write first (offline-first source of truth)
    await _box.put(wallet.id, wallet);

    // 2. Attempt Firestore sync in background (fire-and-forget so offline execution never hangs)
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      unawaited(
        fs
            .collection('users')
            .doc(uid)
            .collection('wallets')
            .doc(wallet.id)
            .set(wallet.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 3))
            .catchError((_) {}),
      );
    }
  }

  Future<void> deleteWallet(String id) async {
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
            .collection('wallets')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 3))
            .catchError((_) {}),
      );
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
        // Hive is the local source of truth. Never overwrite a locally
        // reconciled wallet with an older Firestore snapshot during startup.
        // Firestore is used here to fill wallets that do not exist locally
        // yet (for example after installing on a second device).
        if (!_box.containsKey(wallet.id)) {
          await _box.put(wallet.id, wallet);
        }
      }
    } catch (_) {
      // Offline fallback
    }
  }
}
