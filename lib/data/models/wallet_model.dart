import 'package:hive/hive.dart';

part 'wallet_model.g.dart';

@HiveType(typeId: 0)
class Wallet extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String type; // kash | muhafazati | jawali | other

  @HiveField(3)
  final int colorValue;

  @HiveField(4)
  final int iconCodePoint;

  @HiveField(5)
  final double openingBalance;

  @HiveField(6)
  final bool isFavorite;

  @HiveField(7)
  final DateTime createdAt;

  Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.iconCodePoint,
    required this.openingBalance,
    this.isFavorite = false,
    required this.createdAt,
  });

  Wallet copyWith({
    String? id,
    String? name,
    String? type,
    int? colorValue,
    int? iconCodePoint,
    double? openingBalance,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      openingBalance: openingBalance ?? this.openingBalance,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'openingBalance': openingBalance,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      colorValue: (map['colorValue'] as num).toInt(),
      iconCodePoint: (map['iconCodePoint'] as num).toInt(),
      openingBalance: (map['openingBalance'] as num).toDouble(),
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
