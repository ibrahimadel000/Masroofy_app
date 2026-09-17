import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 1)
class TransactionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String walletId;

  @HiveField(2)
  final String type; // expense | income | adjustment

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String category; // أكل | مواصلات | بقالة | فواتير | تحويل | راتب | أخرى

  @HiveField(5)
  final String? note;

  @HiveField(6)
  final DateTime date;

  @HiveField(7)
  final String source; // manual | sms | adjustment

  @HiveField(8)
  final String? smsKey;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final String? rawSmsBody;

  @HiveField(11)
  final String? rawSmsSender;

  TransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.source,
    this.smsKey,
    required this.createdAt,
    this.rawSmsBody,
    this.rawSmsSender,
  });

  TransactionModel copyWith({
    String? id,
    String? walletId,
    String? type,
    double? amount,
    String? category,
    String? note,
    DateTime? date,
    String? source,
    String? smsKey,
    DateTime? createdAt,
    String? rawSmsBody,
    String? rawSmsSender,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      source: source ?? this.source,
      smsKey: smsKey ?? this.smsKey,
      createdAt: createdAt ?? this.createdAt,
      rawSmsBody: rawSmsBody ?? this.rawSmsBody,
      rawSmsSender: rawSmsSender ?? this.rawSmsSender,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walletId': walletId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'source': source,
      'smsKey': smsKey,
      'createdAt': createdAt.toIso8601String(),
      'rawSmsBody': rawSmsBody,
      'rawSmsSender': rawSmsSender,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      walletId: map['walletId'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      source: map['source'] as String,
      smsKey: map['smsKey'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      rawSmsBody: map['rawSmsBody'] as String?,
      rawSmsSender: map['rawSmsSender'] as String?,
    );
  }

  /// Extracts transaction reference number from note or rawSmsBody if available
  String? get referenceNumber {
    final text = rawSmsBody ?? note;
    if (text == null || text.isEmpty) return null;
    final patterns = [
      RegExp(r'(?:المرجع|مرجع|ref(?:erence)?|رقم العملية|رقم المرجع|رقم الحوالة)[\s:]*([0-9a-zA-Z]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty && val.length >= 4) {
          return val;
        }
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          walletId == other.walletId &&
          type == other.type &&
          amount == other.amount &&
          category == other.category &&
          note == other.note &&
          date == other.date &&
          source == other.source &&
          smsKey == other.smsKey;

  @override
  int get hashCode => Object.hash(
        id,
        walletId,
        type,
        amount,
        category,
        note,
        date,
        source,
        smsKey,
      );
}
