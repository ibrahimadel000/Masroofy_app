import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

class DatabaseService {
  static const String legacyBoxWallets = 'walletsBox';
  static const String legacyBoxTransactions = 'transactionsBox';
  static const String legacyBoxSmsKeys = 'smsKeysBox';

  static Box<Wallet>? _activeWalletsBox;
  static Box<TransactionModel>? _activeTransactionsBox;
  static Box<bool>? _activeSmsKeysBox;
  static String? _currentUserId;

  static bool _isHiveInitialized = false;

  static bool get isInitialized => _isHiveInitialized;

  static void markInitializedForTesting([bool initialized = true]) {
    _isHiveInitialized = initialized;
  }

  static String? get currentUserId => _currentUserId;

  static Future<void> init({String? initialUserId}) async {
    await Hive.initFlutter();
    _isHiveInitialized = true;

    // Register Hive Adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WalletAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }

    await switchUser(initialUserId ?? 'guest');
  }

  static String sanitizeUserId(String? userId) {
    if (userId == null || userId.trim().isEmpty) return 'guest';
    return userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<void> switchUser(String? userId) async {
    final sanitizedId = sanitizeUserId(userId);
    _currentUserId = sanitizedId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', sanitizedId);
    } catch (_) {}

    if (!_isHiveInitialized) {
      // Hive has not been initialized (e.g. lightweight widget unit tests).
      return;
    }

    if (_activeWalletsBox != null &&
        _activeWalletsBox!.isOpen &&
        _activeTransactionsBox != null &&
        _activeTransactionsBox!.isOpen &&
        _activeSmsKeysBox != null &&
        _activeSmsKeysBox!.isOpen &&
        _activeWalletsBox!.name == 'wallets_$sanitizedId') {
      return;
    }

    final walletsBoxName = 'wallets_$sanitizedId';
    final transactionsBoxName = 'transactions_$sanitizedId';
    final smsKeysBoxName = 'sms_keys_$sanitizedId';

    try {
      _activeWalletsBox = await Hive.openBox<Wallet>(walletsBoxName);
      _activeTransactionsBox = await Hive.openBox<TransactionModel>(transactionsBoxName);
      _activeSmsKeysBox = await Hive.openBox<bool>(smsKeysBoxName);

      // One-time legacy migration if the active user's box is empty
      await _migrateLegacyIfNeeded(_activeWalletsBox!, _activeTransactionsBox!, _activeSmsKeysBox!);
    } catch (_) {
      // In test environments where Hive storage path is not initialized, don't throw
    }
  }

  static Future<void> _migrateLegacyIfNeeded(
    Box<Wallet> walletsBox,
    Box<TransactionModel> txBox,
    Box<bool> smsBox,
  ) async {
    try {
      if (walletsBox.isEmpty && await Hive.boxExists(legacyBoxWallets)) {
        final legacyWallets = await Hive.openBox<Wallet>(legacyBoxWallets);
        if (legacyWallets.isNotEmpty) {
          for (final key in legacyWallets.keys) {
            final val = legacyWallets.get(key);
            if (val != null) {
              await walletsBox.put(key, val);
            }
          }
          await legacyWallets.clear();
        }
      }

      if (txBox.isEmpty && await Hive.boxExists(legacyBoxTransactions)) {
        final legacyTx = await Hive.openBox<TransactionModel>(legacyBoxTransactions);
        if (legacyTx.isNotEmpty) {
          for (final key in legacyTx.keys) {
            final val = legacyTx.get(key);
            if (val != null) {
              await txBox.put(key, val);
            }
          }
          await legacyTx.clear();
        }
      }

      if (smsBox.isEmpty && await Hive.boxExists(legacyBoxSmsKeys)) {
        final legacySms = await Hive.openBox<bool>(legacyBoxSmsKeys);
        if (legacySms.isNotEmpty) {
          for (final key in legacySms.keys) {
            final val = legacySms.get(key);
            if (val != null) {
              await smsBox.put(key, val);
            }
          }
          await legacySms.clear();
        }
      }
    } catch (_) {
      // Ignore migration errors gracefully
    }
  }

  /// Migrates all data from the guest/local vault to the authenticated user's database.
  /// Transfers wallets, transactions, and SMS deduplication keys, then clears the local guest vault.
  static Future<int> migrateGuestDataToUser(String targetUserId) async {
    final sanitizedTarget = sanitizeUserId(targetUserId);
    if (sanitizedTarget == 'guest') return 0;
    if (!_isHiveInitialized) return 0;

    int migratedItems = 0;
    try {
      final guestWallets = await Hive.openBox<Wallet>('wallets_guest');
      final guestTxs = await Hive.openBox<TransactionModel>('transactions_guest');
      final guestSms = await Hive.openBox<bool>('sms_keys_guest');

      if (guestWallets.isEmpty && guestTxs.isEmpty && guestSms.isEmpty) {
        return 0;
      }

      final targetWallets = await Hive.openBox<Wallet>('wallets_$sanitizedTarget');
      final targetTxs = await Hive.openBox<TransactionModel>('transactions_$sanitizedTarget');
      final targetSms = await Hive.openBox<bool>('sms_keys_$sanitizedTarget');

      for (final key in guestWallets.keys) {
        final wallet = guestWallets.get(key);
        if (wallet != null) {
          await targetWallets.put(key, wallet);
          migratedItems++;
        }
      }

      for (final key in guestTxs.keys) {
        final tx = guestTxs.get(key);
        if (tx != null) {
          await targetTxs.put(key, tx);
          migratedItems++;
        }
      }

      for (final key in guestSms.keys) {
        final val = guestSms.get(key);
        if (val != null) {
          await targetSms.put(key, val);
        }
      }

      // Clear guest boxes after successful transfer
      await guestWallets.clear();
      await guestTxs.clear();
      await guestSms.clear();
    } catch (_) {
      // Gracefully handle any migration errors
    }

    return migratedItems;
  }

  /// Resets and clears all local guest vault data (wallets, transactions, sms keys).
  static Future<void> resetGuestData() async {
    if (!_isHiveInitialized) return;
    try {
      final guestWallets = await Hive.openBox<Wallet>('wallets_guest');
      final guestTxs = await Hive.openBox<TransactionModel>('transactions_guest');
      final guestSms = await Hive.openBox<bool>('sms_keys_guest');

      await guestWallets.clear();
      await guestTxs.clear();
      await guestSms.clear();
    } catch (_) {
      // Gracefully ignore in non-hive environments
    }
  }

  static Box<Wallet> get walletsBox {
    if (_activeWalletsBox != null && _activeWalletsBox!.isOpen) {
      return _activeWalletsBox!;
    }
    final boxName = 'wallets_${_currentUserId ?? 'guest'}';
    if (Hive.isBoxOpen(boxName)) {
      _activeWalletsBox = Hive.box<Wallet>(boxName);
      return _activeWalletsBox!;
    }
    if (Hive.isBoxOpen(legacyBoxWallets)) {
      return Hive.box<Wallet>(legacyBoxWallets);
    }
    throw StateError('Wallets box is not open. Call DatabaseService.switchUser() first.');
  }

  static Box<TransactionModel> get transactionsBox {
    if (_activeTransactionsBox != null && _activeTransactionsBox!.isOpen) {
      return _activeTransactionsBox!;
    }
    final boxName = 'transactions_${_currentUserId ?? 'guest'}';
    if (Hive.isBoxOpen(boxName)) {
      _activeTransactionsBox = Hive.box<TransactionModel>(boxName);
      return _activeTransactionsBox!;
    }
    if (Hive.isBoxOpen(legacyBoxTransactions)) {
      return Hive.box<TransactionModel>(legacyBoxTransactions);
    }
    throw StateError('Transactions box is not open. Call DatabaseService.switchUser() first.');
  }

  static Box<bool> get smsKeysBox {
    if (_activeSmsKeysBox != null && _activeSmsKeysBox!.isOpen) {
      return _activeSmsKeysBox!;
    }
    final boxName = 'sms_keys_${_currentUserId ?? 'guest'}';
    if (Hive.isBoxOpen(boxName)) {
      _activeSmsKeysBox = Hive.box<bool>(boxName);
      return _activeSmsKeysBox!;
    }
    if (Hive.isBoxOpen(legacyBoxSmsKeys)) {
      return Hive.box<bool>(legacyBoxSmsKeys);
    }
    throw StateError('Sms keys box is not open. Call DatabaseService.switchUser() first.');
  }
}
