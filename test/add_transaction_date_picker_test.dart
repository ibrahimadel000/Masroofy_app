import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/app.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/features/transactions/screens/add_transaction_screen.dart';

class FakeAuthRepo extends AuthRepository {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> get authStateChanges => Stream.value(null);
}

class MockWalletRepo extends WalletRepository {
  @override
  List<Wallet> getWallets() => [
        Wallet(
          id: 'w1',
          name: 'الكريمي',
          type: 'kuraimi',
          colorValue: 0xFF0E7C61,
          iconCodePoint: Icons.account_balance_wallet.codePoint,
          openingBalance: 50000,
          currencyCode: 'YER',
          createdAt: DateTime.now(),
        ),
      ];
}

class MockTxRepo extends TransactionRepository {
  @override
  List<TransactionModel> getTransactions() => [];
  @override
  List<TransactionModel> getTransactionsByWallet(String walletId) => [];
}

void main() {
  testWidgets('AddTransactionScreen date picker opens without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({'guestLoggedIn': true});
    final prefs = await SharedPreferences.getInstance();

    final wRepo = MockWalletRepo();
    final txRepo = MockTxRepo();
    final authRepo = FakeAuthRepo();

    await tester.pumpWidget(
      MizaanApp(
        prefs: prefs,
        authRepository: authRepo,
        walletRepository: wRepo,
        transactionRepository: txRepo,
        homeOverride: const AddTransactionScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final dateFieldFinder = find.text('التاريخ والوقت');
    expect(dateFieldFinder, findsOneWidget);

    // Scroll to date picker container and tap it
    await tester.ensureVisible(dateFieldFinder);
    await tester.pumpAndSettle();

    await tester.tap(dateFieldFinder);
    await tester.pumpAndSettle();

    // Check if bottom sheet opened
    expect(find.text('تحديد تاريخ ووقت الحركة'), findsOneWidget);

    // Tap on Date card to open showDatePicker
    expect(find.text('التاريخ (اضغط للتقويم)'), findsOneWidget);
    await tester.tap(find.text('التاريخ (اضغط للتقويم)'));
    await tester.pumpAndSettle();

    // Verify calendar dialog opened
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Dismiss date picker dialog by tapping "حسنًا"
    final dateOk = find.text('حسنًا');
    expect(dateOk, findsOneWidget);
    await tester.tap(dateOk);
    await tester.pumpAndSettle();

    // Tap on Time card to open showTimePicker
    expect(find.text('الوقت (اضغط للتغيير)'), findsOneWidget);
    await tester.tap(find.text('الوقت (اضغط للتغيير)'));
    await tester.pumpAndSettle();

    // Verify time picker dialog opened
    expect(find.byType(TimePickerDialog), findsOneWidget);

    // Dismiss time picker dialog by tapping "حسنًا"
    final timeOk = find.text('حسنًا');
    expect(timeOk, findsOneWidget);
    await tester.tap(timeOk);
    await tester.pumpAndSettle();

    // Tap on "اليوم" quick chip
    final todayChip = find.text('اليوم');
    expect(todayChip, findsOneWidget);
    await tester.tap(todayChip);
    await tester.pumpAndSettle();

    // Confirm selection
    final confirmBtn = find.text('اعتماد التاريخ والوقت');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Bottom sheet is closed and main screen is visible
    expect(find.text('تحديد تاريخ ووقت الحركة'), findsNothing);
    expect(find.text('تسجيل المصروف'), findsOneWidget);
  });
}
