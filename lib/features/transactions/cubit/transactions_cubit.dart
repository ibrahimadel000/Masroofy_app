import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/utils/balance_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract class TransactionsState extends Equatable {
  const TransactionsState();

  @override
  List<Object?> get props => [];
}

class TransactionsInitial extends TransactionsState {}

class TransactionsLoading extends TransactionsState {}

class TransactionsLoaded extends TransactionsState {
  final List<TransactionModel> transactions;

  const TransactionsLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class TransactionsError extends TransactionsState {
  final String message;

  const TransactionsError(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionsCubit extends Cubit<TransactionsState> {
  final TransactionRepository repository;
  final WalletRepository? walletRepository;
  final NotificationService? notificationService;
  final SharedPreferences? prefs;

  TransactionsCubit({
    required this.repository,
    this.walletRepository,
    this.notificationService,
    this.prefs,
  }) : super(TransactionsInitial()) {
    loadTransactions();
  }

  void loadTransactions() {
    try {
      emit(TransactionsLoading());
      final list = repository.getTransactions();
      emit(TransactionsLoaded(list));
    } catch (e) {
      emit(TransactionsError('فشل تحميل الحركات: $e'));
    }
  }

  void reset() {
    emit(const TransactionsLoaded([]));
  }

  Future<void> addTransaction({
    required String walletId,
    required String type,
    required double amount,
    required String category,
    String? note,
    required DateTime date,
    String source = 'manual',
    String? smsKey,
  }) async {
    try {
      final tx = TransactionModel(
        id: const Uuid().v4(),
        walletId: walletId,
        type: type,
        amount: amount,
        category: category,
        note: note?.trim(),
        date: date,
        source: source,
        smsKey: smsKey,
        createdAt: DateTime.now(),
      );
      await repository.saveTransaction(tx);
      loadTransactions();
      _checkLowBalanceAlert(tx);
    } catch (e) {
      emit(TransactionsError('فشل تسجيل الحركة: $e'));
    }
  }

  Future<void> _checkLowBalanceAlert(TransactionModel tx) async {
    if (tx.type != 'expense') return;
    try {
      final notif = notificationService ?? NotificationService();
      final wRepo = walletRepository ?? WalletRepository();
      final wallet = wRepo.getWalletById(tx.walletId);
      if (wallet != null) {
        final txs = repository.getTransactionsByWallet(wallet.id);
        final currentBal = BalanceCalculator.calculateWalletBalance(
          openingBalance: wallet.openingBalance,
          transactions: txs,
        );
        final sp = prefs ?? await SharedPreferences.getInstance();
        final uid = DatabaseService.currentUserId ?? 'guest';
        final threshold = sp.getDouble('${uid}_lowBalanceThreshold') ??
            sp.getDouble('lowBalanceThreshold') ??
            10000.0;
        if (currentBal < threshold) {
          await notif.showLowBalanceAlert(
            walletName: wallet.name,
            currentBalance: currentBal,
            threshold: threshold,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    try {
      await repository.saveTransaction(tx);
      loadTransactions();
      _checkLowBalanceAlert(tx);
    } catch (e) {
      emit(TransactionsError('فشل تعديل الحركة: $e'));
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await repository.deleteTransaction(id);
      loadTransactions();
    } catch (e) {
      emit(TransactionsError('فشل حذف الحركة: $e'));
    }
  }
}
