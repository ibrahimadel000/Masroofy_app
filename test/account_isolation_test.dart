import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/features/transactions/cubit/transactions_cubit.dart';
import 'package:mizaan/features/wallets/cubit/wallets_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mizaan_isolation_test_');
    Hive.init(tempDir.path);
    DatabaseService.markInitializedForTesting(true);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(WalletAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    DatabaseService.markInitializedForTesting(false);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Multi-Account Data & Setup Isolation Tests', () {
    test('User B does not see User A wallets or transactions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // 1. Setup User A (user_111)
      await DatabaseService.switchUser('user_111');
      final walletRepo = WalletRepository();
      final txRepo = TransactionRepository();
      final walletsCubit = WalletsCubit(repository: walletRepo);
      final txCubit = TransactionsCubit(repository: txRepo, prefs: prefs);

      // Verify User A starts with 0 wallets
      expect((walletsCubit.state as WalletsLoaded).wallets, isEmpty);

      // User A creates their setup
      await walletsCubit.addWallet(
        name: 'كريمي كاش أحمد',
        type: 'kuraimi',
        colorValue: 0xFF0E7C61,
        iconCodePoint: 0xe000,
        openingBalance: 250000.0,
      );

      final userAWallets = (walletsCubit.state as WalletsLoaded).wallets;
      expect(userAWallets.length, 1);
      expect(userAWallets.first.name, 'كريمي كاش أحمد');

      await txCubit.addTransaction(
        walletId: userAWallets.first.id,
        type: 'income',
        amount: 100000.0,
        category: 'راتب',
        date: DateTime.now(),
      );

      expect((txCubit.state as TransactionsLoaded).transactions.length, 1);

      // 2. User A logs out -> Cubits reset
      walletsCubit.reset();
      txCubit.reset();
      expect((walletsCubit.state as WalletsLoaded).wallets, isEmpty);
      expect((txCubit.state as TransactionsLoaded).transactions, isEmpty);

      // 3. User B (user_222) registers and logs in
      await DatabaseService.switchUser('user_222');
      walletsCubit.loadWallets();
      txCubit.loadTransactions();

      // CRITICAL ASSERTION: User B must have 0 wallets and 0 transactions!
      expect((walletsCubit.state as WalletsLoaded).wallets, isEmpty);
      expect((txCubit.state as TransactionsLoaded).transactions, isEmpty);

      // 4. User B creates their own setup
      await walletsCubit.addWallet(
        name: 'محفظة جيب خالد',
        type: 'jaib',
        colorValue: 0xFF1E88E5,
        iconCodePoint: 0xe001,
        openingBalance: 50000.0,
      );

      final userBWallets = (walletsCubit.state as WalletsLoaded).wallets;
      expect(userBWallets.length, 1);
      expect(userBWallets.first.name, 'محفظة جيب خالد');

      // 5. User B logs out -> User A logs back in
      walletsCubit.reset();
      txCubit.reset();

      await DatabaseService.switchUser('user_111');
      walletsCubit.loadWallets();
      txCubit.loadTransactions();

      // CRITICAL ASSERTION: User A's data is fully preserved and does not contain User B's wallet
      final reloadedUserAWallets = (walletsCubit.state as WalletsLoaded).wallets;
      expect(reloadedUserAWallets.length, 1);
      expect(reloadedUserAWallets.first.name, 'كريمي كاش أحمد');
      expect((txCubit.state as TransactionsLoaded).transactions.length, 1);

      await walletsCubit.close();
      await txCubit.close();
    });
  });
}
