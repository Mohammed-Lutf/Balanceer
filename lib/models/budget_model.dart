import 'package:uuid/uuid.dart';

/// Budget Model
class BudgetModel {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final int month;
  final int year;
  final DateTime createdAt;
  final bool isSynced;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.month,
    required this.year,
    required this.createdAt,
    this.isSynced = false,
  });

  factory BudgetModel.create({
    required String userId,
    required String category,
    required double amount,
    required int month,
    required int year,
  }) {
    return BudgetModel(
      id: const Uuid().v4(),
      userId: userId,
      category: category,
      amount: amount,
      month: month,
      year: year,
      createdAt: DateTime.now(),
      isSynced: false,
    );
  }

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: json['is_synced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalJson() {
    return {
      ...toJson(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory BudgetModel.fromLocalJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: (json['is_synced'] as int?) == 1,
    );
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? category,
    double? amount,
    int? month,
    int? year,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
