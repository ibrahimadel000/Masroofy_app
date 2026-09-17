import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:mizaan/data/models/transaction_model.dart';
import 'package:mizaan/data/models/wallet_model.dart';
import 'package:mizaan/data/repositories/transaction_repository.dart';
import 'package:mizaan/data/repositories/wallet_repository.dart';
import 'package:mizaan/data/services/sms_service.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/features/sms/cubit/sms_state.dart';

class SmsCubit extends Cubit<SmsState> {
  final SmsService smsService;
  final TransactionRepository transactionRepository;
  final WalletRepository? walletRepository;
  final NotificationService? notificationService;

  SmsCubit({
    required this.smsService,
    required this.transactionRepository,
    this.walletRepository,
    this.notificationService,
  }) : super(SmsInitial());

  void reset() {
    emit(SmsInitial());
  }

  /// Request permission and scan inbox
  Future<void> scanSms({
    required List<Wallet> wallets,
    Map<String, String>? customMappings,
  }) async {
    try {
      final granted = await smsService.requestPermission();
      if (!granted) {
        emit(SmsPermissionRequired());
        return;
      }

      emit(SmsScanning());

      final items = await smsService.scanRecentWalletSms(
        transactionRepository: transactionRepository,
        userWallets: wallets,
        customMappings: customMappings,
      );

      emit(SmsLoaded(items: items, totalScanned: items.length));
    } catch (e) {
      emit(SmsError('حدث خطأ أثناء فحص الرسائل: $e'));
    }
  }

  /// Toggle selection for an item
  void toggleSelect(int index) {
    if (state is SmsLoaded) {
      final current = (state as SmsLoaded);
      final updatedList = List<SmsCandidateItem>.from(current.items);
      final item = updatedList[index];
      item.isSelected = !item.isSelected;
      emit(SmsLoaded(items: updatedList, totalScanned: current.totalScanned));
    }
  }

  /// Select or deselect all items
  void toggleSelectAll(bool select) {
    if (state is SmsLoaded) {
      final current = (state as SmsLoaded);
      final updatedList = current.items.map((item) {
        item.isSelected = select;
        return item;
      }).toList();
      emit(SmsLoaded(items: updatedList, totalScanned: current.totalScanned));
    }
  }

  /// Change assigned wallet for an item
  void setTargetWallet(int index, String walletId) {
    if (state is SmsLoaded) {
      final current = (state as SmsLoaded);
      final updatedList = List<SmsCandidateItem>.from(current.items);
      updatedList[index].targetWalletId = walletId;
      emit(SmsLoaded(items: updatedList, totalScanned: current.totalScanned));
    }
  }

  /// Confirm and save all selected transactions
  Future<int> importSelected() async {
    if (state is! SmsLoaded) return 0;
    final current = (state as SmsLoaded);
    final selectedItems = current.items.where((i) => i.isSelected).toList();

    if (selectedItems.isEmpty) return 0;

    emit(SmsImporting());

    int count = 0;
    try {
      final wRepo = walletRepository ?? WalletRepository();

      // 1. Sort items chronologically (oldest first, newest last)
      selectedItems.sort((a, b) => a.data.date.compareTo(b.data.date));

      final Map<String, double> latestBalancesByWallet = {};

      for (final item in selectedItems) {
        final walletId = item.targetWalletId;
        if (walletId == null) continue;

        if (item.data.balance != null) {
          latestBalancesByWallet[walletId] = item.data.balance!;
        }

        if (item.data.isBalanceOnly) {
          count++;
        } else {
          // Check for duplicates before saving
          if (transactionRepository.isDuplicateSms(
            smsKey: item.data.smsKey,
            referenceNumber: item.data.referenceNumber,
            rawSmsBody: item.data.rawBody,
            walletId: walletId,
            amount: item.data.amount,
            type: item.data.type,
            date: item.data.date,
          )) {
            continue;
          }

          final tx = TransactionModel(
            id: const Uuid().v4(),
            walletId: walletId,
            type: item.data.type,
            amount: item.data.amount,
            category: item.data.category,
            note: item.data.rawBody,
            date: item.data.date,
            source: 'sms',
            smsKey: item.data.smsKey,
            createdAt: DateTime.now(),
            rawSmsBody: item.data.rawBody,
            rawSmsSender: item.data.rawSender,
          );

          await transactionRepository.saveTransaction(tx);
          count++;
        }
      }

      // 2. Reconcile each wallet ONCE with its newest verified bank balance
      for (final entry in latestBalancesByWallet.entries) {
        final walletId = entry.key;
        final targetBalance = entry.value;
        final freshWallet = wRepo.getWalletById(walletId);
        if (freshWallet != null) {
          final txs = transactionRepository.getTransactionsByWallet(walletId);
          double txSum = 0.0;
          for (final t in txs) {
            if (t.type == 'income') {
              txSum += t.amount;
            } else if (t.type == 'expense') {
              txSum -= t.amount;
            } else if (t.type == 'adjustment') {
              txSum += t.amount;
            }
          }
          final targetOpening = targetBalance - txSum;
          if ((targetOpening - freshWallet.openingBalance).abs() >= 0.01) {
            final updatedWallet = freshWallet.copyWith(
              openingBalance: targetOpening,
            );
            await wRepo.saveWallet(updatedWallet);
          }
        }
      }

      emit(SmsImportSuccess(count));
      return count;
    } catch (e) {
      emit(SmsError('فشل حفظ الحركات: $e'));
      return count;
    }
  }

  /// Silent background auto-import for app start
  Future<int> autoImportSilently({
    required List<Wallet> wallets,
    Map<String, String>? customMappings,
  }) async {
    try {
      final hasPerm = await smsService.hasPermission();
      if (!hasPerm) return 0;

      final items = await smsService.scanRecentWalletSms(
        transactionRepository: transactionRepository,
        userWallets: wallets,
        customMappings: customMappings,
      );

      int count = 0;
      final List<SmsCandidateItem> importedItems = [];
      final wRepo = walletRepository ?? WalletRepository();

      // 1. Sort items chronologically (oldest first, newest last)
      final sortedItems = List<SmsCandidateItem>.from(items)
        ..sort((a, b) => a.data.date.compareTo(b.data.date));

      final Map<String, double> latestBalancesByWallet = {};

      for (final item in sortedItems) {
        final walletId = item.targetWalletId;
        if (walletId == null) continue;

        if (item.data.balance != null) {
          latestBalancesByWallet[walletId] = item.data.balance!;
        }

        if (item.data.isBalanceOnly) {
          count++;
        } else {
          // Check for duplicates before saving
          if (transactionRepository.isDuplicateSms(
            smsKey: item.data.smsKey,
            referenceNumber: item.data.referenceNumber,
            rawSmsBody: item.data.rawBody,
            walletId: walletId,
            amount: item.data.amount,
            type: item.data.type,
            date: item.data.date,
          )) {
            continue;
          }

          final tx = TransactionModel(
            id: const Uuid().v4(),
            walletId: walletId,
            type: item.data.type,
            amount: item.data.amount,
            category: item.data.category,
            note: item.data.rawBody,
            date: item.data.date,
            source: 'sms',
            smsKey: item.data.smsKey,
            createdAt: DateTime.now(),
            rawSmsBody: item.data.rawBody,
            rawSmsSender: item.data.rawSender,
          );

          await transactionRepository.saveTransaction(tx);
          importedItems.add(item);
          count++;
        }
      }

      // 2. Reconcile each wallet ONCE with its newest verified bank balance
      for (final entry in latestBalancesByWallet.entries) {
        final walletId = entry.key;
        final targetBalance = entry.value;
        final freshWallet = wRepo.getWalletById(walletId);
        if (freshWallet != null) {
          final txs = transactionRepository.getTransactionsByWallet(walletId);
          double txSum = 0.0;
          for (final t in txs) {
            if (t.type == 'income') {
              txSum += t.amount;
            } else if (t.type == 'expense') {
              txSum -= t.amount;
            } else if (t.type == 'adjustment') {
              txSum += t.amount;
            }
          }
          final targetOpening = targetBalance - txSum;
          if ((targetOpening - freshWallet.openingBalance).abs() >= 0.01) {
            final updatedWallet = freshWallet.copyWith(
              openingBalance: targetOpening,
            );
            await wRepo.saveWallet(updatedWallet);
          }
        }
      }

      if (count > 0) {
        final prefs = await SharedPreferences.getInstance();
        final uid = DatabaseService.currentUserId ?? 'guest';
        final notifEnabled = prefs.getBool('${uid}_smsNotificationsEnabled') ??
            prefs.getBool('smsNotificationsEnabled') ??
            true;

        if (notifEnabled) {
          final notif = notificationService ?? NotificationService();
          if (count == 1) {
            final firstItem = importedItems.first;
            final wallet = wallets.firstWhere(
              (w) => w.id == firstItem.targetWalletId,
              orElse: () => wallets.first,
            );
            await SmsService.sendTransactionNotification(
              notificationService: notif,
              data: firstItem.data,
              walletName: wallet.name,
              currencyCode: wallet.currencyCode,
            );
          } else {
            await notif.showTransactionAlert(
              title: '📥 حركات جديدة في المحافظ',
              body: 'تم استيراد $count حركات مالية وتحديث أرصدة محافظك تلقائياً.',
            );
          }
        }
      }

      return count;
    } catch (_) {
      return 0;
    }
  }
}
