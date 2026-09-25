import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/utils/stats_calculator.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/features/stats/cubit/stats_state.dart';

class StatsCubit extends Cubit<StatsState> {
  final TransactionRepository transactionRepository;
  final WalletRepository walletRepository;

  StatsCubit({
    required this.transactionRepository,
    required this.walletRepository,
  }) : super(StatsInitial()) {
    loadStats();
  }

  void reset() {
    emit(StatsInitial());
  }

  DateTime _resolveReferenceDate(DateTime target) {
    final realNow = DateTime.now();
    if (target.year == realNow.year && target.month == realNow.month) {
      return realNow;
    }
    // For past or future months, set to end of that month
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, lastDay, 23, 59, 59);
  }

  void loadStats({DateTime? targetMonth, String? walletId}) {
    try {
      final currentLoaded = state is StatsLoaded
          ? (state as StatsLoaded)
          : null;
      if (currentLoaded == null) {
        emit(StatsLoading());
      }

      final effectiveMonth =
          targetMonth ?? (currentLoaded?.selectedMonth ?? DateTime.now());
      final now = _resolveReferenceDate(effectiveMonth);
      final effectiveWalletId = walletId ?? currentLoaded?.selectedWalletId;
      final timeframe = currentLoaded?.timeframe ?? StatsTimeframe.week;
      final activeType = currentLoaded?.activeType ?? 'expense';

      final transactions = transactionRepository.getTransactions();
      final wallets = walletRepository.getWallets();

      final result = StatsCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        referenceDate: now,
        walletId: effectiveWalletId,
      );

      emit(
        StatsLoaded(
          result: result,
          timeframe: timeframe,
          selectedMonth: effectiveMonth,
          selectedWalletId: effectiveWalletId,
          activeType: activeType,
        ),
      );
    } catch (e) {
      emit(StatsError('فشل تحميل الإحصائيات: $e'));
    }
  }

  void updateData({
    required List<TransactionModel> transactions,
    required List<Wallet> wallets,
    DateTime? referenceDate,
    String? walletId,
  }) {
    final currentLoaded = state is StatsLoaded ? (state as StatsLoaded) : null;
    final effectiveMonth =
        referenceDate ?? (currentLoaded?.selectedMonth ?? DateTime.now());
    final now = _resolveReferenceDate(effectiveMonth);
    final effectiveWalletId = walletId ?? currentLoaded?.selectedWalletId;
    final timeframe = currentLoaded?.timeframe ?? StatsTimeframe.week;
    final activeType = currentLoaded?.activeType ?? 'expense';

    final result = StatsCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      referenceDate: now,
      walletId: effectiveWalletId,
    );

    emit(
      StatsLoaded(
        result: result,
        timeframe: timeframe,
        selectedMonth: effectiveMonth,
        selectedWalletId: effectiveWalletId,
        activeType: activeType,
      ),
    );
  }

  void switchTimeframe(StatsTimeframe timeframe) {
    if (state is StatsLoaded) {
      final current = state as StatsLoaded;
      emit(current.copyWith(timeframe: timeframe));
    }
  }

  void switchActiveType(String activeType) {
    if (state is StatsLoaded) {
      final current = state as StatsLoaded;
      emit(current.copyWith(activeType: activeType));
    }
  }

  void filterByWallet(String? walletId) {
    if (state is StatsLoaded) {
      final current = state as StatsLoaded;
      final transactions = transactionRepository.getTransactions();
      final wallets = walletRepository.getWallets();
      final now = _resolveReferenceDate(current.selectedMonth);

      final result = StatsCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        referenceDate: now,
        walletId: walletId,
      );

      emit(current.copyWith(result: result, selectedWalletId: () => walletId));
    } else {
      loadStats(walletId: walletId);
    }
  }

  void changeMonth(DateTime month) {
    loadStats(targetMonth: month);
  }
}
