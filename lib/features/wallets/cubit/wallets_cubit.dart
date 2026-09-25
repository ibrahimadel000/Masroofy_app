import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';

abstract class WalletsState extends Equatable {
  const WalletsState();

  @override
  List<Object?> get props => [];
}

class WalletsInitial extends WalletsState {}

class WalletsLoading extends WalletsState {}

class WalletsLoaded extends WalletsState {
  final List<Wallet> wallets;

  const WalletsLoaded(this.wallets);

  @override
  List<Object?> get props => [wallets];
}

class WalletsError extends WalletsState {
  final String message;

  const WalletsError(this.message);

  @override
  List<Object?> get props => [message];
}

class WalletsCubit extends Cubit<WalletsState> {
  final WalletRepository repository;
  final TransactionRepository transactionRepository;

  WalletsCubit({
    required this.repository,
    TransactionRepository? transactionRepository,
  }) : transactionRepository = transactionRepository ?? TransactionRepository(),
       super(WalletsInitial()) {
    loadWallets();
  }

  void loadWallets() {
    try {
      emit(WalletsLoading());
      final list = repository.getWallets();
      emit(WalletsLoaded(list));
    } catch (e) {
      emit(WalletsError('فشل تحميل المحافظ: $e'));
    }
  }

  void reset() {
    emit(const WalletsLoaded([]));
  }

  Future<void> addWallet({
    required String name,
    required String type,
    required int colorValue,
    required int iconCodePoint,
    required double openingBalance,
    String currencyCode = 'YER',
  }) async {
    try {
      final wallet = Wallet(
        id: const Uuid().v4(),
        name: name.trim(),
        type: type,
        colorValue: colorValue,
        iconCodePoint: iconCodePoint,
        openingBalance: openingBalance,
        currencyCode: currencyCode,
        createdAt: DateTime.now(),
      );
      await repository.saveWallet(wallet);
      loadWallets();
    } catch (e) {
      emit(WalletsError('فشل إضافة المحفظة: $e'));
    }
  }

  Future<void> toggleFavorite(String id) async {
    try {
      await repository.toggleFavorite(id);
      loadWallets();
    } catch (e) {
      emit(WalletsError('فشل تحديث المفضلة: $e'));
    }
  }

  Future<void> deleteWallet(String id) async {
    try {
      await transactionRepository.deleteTransactionsForWallet(id);
      await repository.deleteWallet(id);
      loadWallets();
    } catch (e) {
      emit(WalletsError('فشل حذف المحفظة: $e'));
    }
  }
}
