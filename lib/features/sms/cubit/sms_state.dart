import 'package:equatable/equatable.dart';
import 'package:mizaan/data/services/sms_service.dart';

abstract class SmsState extends Equatable {
  const SmsState();

  @override
  List<Object?> get props => [];
}

class SmsInitial extends SmsState {}

class SmsPermissionRequired extends SmsState {}

class SmsScanning extends SmsState {}

class SmsLoaded extends SmsState {
  final List<SmsCandidateItem> items;
  final int totalScanned;

  const SmsLoaded({required this.items, required this.totalScanned});

  int get selectedCount => items.where((i) => i.isSelected).length;

  @override
  List<Object?> get props => [items, totalScanned, selectedCount];
}

class SmsImporting extends SmsState {}

class SmsImportSuccess extends SmsState {
  final int importedCount;

  const SmsImportSuccess(this.importedCount);

  @override
  List<Object?> get props => [importedCount];
}

class SmsError extends SmsState {
  final String message;

  const SmsError(this.message);

  @override
  List<Object?> get props => [message];
}
