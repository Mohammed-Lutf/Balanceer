import 'package:uuid/uuid.dart';

/// Expense Categories
enum ExpenseCategory {
  food('طعام', 'food'),
  transport('مواصلات', 'transport'),
  entertainment('ترفيه', 'entertainment'),
  shopping('تسوق', 'shopping'),
  bills('فواتير', 'bills'),
  health('صحة', 'health'),
  education('تعليم', 'education'),
  other('أخرى', 'other');

  final String arabicName;
  final String key;
  const ExpenseCategory(this.arabicName, this.key);

  static ExpenseCategory fromKey(String key) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.key == key,
      orElse: () => ExpenseCategory.other,
    );
  }
}

/// Expense Model
class ExpenseModel {
  final String id;
  final String userId;
  final ExpenseCategory category;
  final double amount;
  final String? notes;
  final DateTime expenseDate;
  final DateTime createdAt;
  final bool isSynced;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    this.notes,
    required this.expenseDate,
    required this.createdAt,
    this.isSynced = false,
  });

  factory ExpenseModel.create({
    required String userId,
    required ExpenseCategory category,
    required double amount,
    String? notes,
    DateTime? expenseDate,
  }) {
    return ExpenseModel(
      id: const Uuid().v4(),
      userId: userId,
      category: category,
      amount: amount,
      notes: notes,
      expenseDate: expenseDate ?? DateTime.now(),
      createdAt: DateTime.now(),
      isSynced: false,
    );
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: ExpenseCategory.fromKey(json['category'] as String),
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: json['is_synced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category.key,
      'amount': amount,
      'notes': notes,
      'expense_date': expenseDate.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalJson() {
    return {
      ...toJson(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ExpenseModel.fromLocalJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: ExpenseCategory.fromKey(json['category'] as String),
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: (json['is_synced'] as int?) == 1,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    ExpenseCategory? category,
    double? amount,
    String? notes,
    DateTime? expenseDate,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
