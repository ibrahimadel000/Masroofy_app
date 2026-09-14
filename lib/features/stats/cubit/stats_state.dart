import 'package:equatable/equatable.dart';
import 'package:mizaan/core/utils/stats_calculator.dart';

enum StatsTimeframe { week, month }

abstract class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {}

class StatsLoading extends StatsState {}

class StatsLoaded extends StatsState {
  final StatsResult result;
  final StatsTimeframe timeframe;
  final DateTime selectedMonth;
  final String? selectedWalletId;
  final String activeType; // 'expense' | 'income'

  const StatsLoaded({
    required this.result,
    this.timeframe = StatsTimeframe.week,
    required this.selectedMonth,
    this.selectedWalletId,
    this.activeType = 'expense',
  });

  StatsLoaded copyWith({
    StatsResult? result,
    StatsTimeframe? timeframe,
    DateTime? selectedMonth,
    String? Function()? selectedWalletId,
    String? activeType,
  }) {
    return StatsLoaded(
      result: result ?? this.result,
      timeframe: timeframe ?? this.timeframe,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedWalletId: selectedWalletId != null ? selectedWalletId() : this.selectedWalletId,
      activeType: activeType ?? this.activeType,
    );
  }

  @override
  List<Object?> get props => [result, timeframe, selectedMonth, selectedWalletId, activeType];
}

class StatsError extends StatsState {
  final String message;

  const StatsError(this.message);

  @override
  List<Object?> get props => [message];
}
