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
  }) : super(StatsInitial());

  void loadStats({DateTime? targetMonth}) {
    try {
      emit(StatsLoading());
      final now = targetMonth ?? DateTime.now();
      final transactions = transactionRepository.getTransactions();
      final wallets = walletRepository.getWallets();

      final result = StatsCalculator.calculate(
        transactions: transactions,
        wallets: wallets,
        referenceDate: now,
      );

      emit(StatsLoaded(
        result: result,
        timeframe: StatsTimeframe.week,
        selectedMonth: now,
      ));
    } catch (e) {
      emit(StatsError('فشل تحميل الإحصائيات: $e'));
    }
  }

  void updateData({
    required List<TransactionModel> transactions,
    required List<Wallet> wallets,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ??
        (state is StatsLoaded ? (state as StatsLoaded).selectedMonth : DateTime.now());
    final result = StatsCalculator.calculate(
      transactions: transactions,
      wallets: wallets,
      referenceDate: now,
    );
    final timeframe =
        state is StatsLoaded ? (state as StatsLoaded).timeframe : StatsTimeframe.week;
    emit(StatsLoaded(
      result: result,
      timeframe: timeframe,
      selectedMonth: now,
    ));
  }

  void switchTimeframe(StatsTimeframe timeframe) {
    if (state is StatsLoaded) {
      final current = state as StatsLoaded;
      emit(current.copyWith(timeframe: timeframe));
    }
  }

  void changeMonth(DateTime month) {
    loadStats(targetMonth: month);
  }
}
