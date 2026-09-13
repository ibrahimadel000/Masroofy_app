import 'package:hive_flutter/hive_flutter.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';

class DatabaseService {
  static const String boxWallets = 'walletsBox';
  static const String boxTransactions = 'transactionsBox';
  static const String boxSmsKeys = 'smsKeysBox';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Hive Adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WalletAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }

    // Open required boxes
    await Hive.openBox<Wallet>(boxWallets);
    await Hive.openBox<TransactionModel>(boxTransactions);
    await Hive.openBox<bool>(boxSmsKeys);
  }

  static Box<Wallet> get walletsBox => Hive.box<Wallet>(boxWallets);
  static Box<TransactionModel> get transactionsBox => Hive.box<TransactionModel>(boxTransactions);
  static Box<bool> get smsKeysBox => Hive.box<bool>(boxSmsKeys);
}
