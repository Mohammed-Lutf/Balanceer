import 'package:uuid/uuid.dart';

enum DebtType {
  debt('دين علي', 'debt'),     // I owe money
  credit('دين لي', 'credit');  // Owed to me

  final String arabicName;
  final String key;
  const DebtType(this.arabicName, this.key);

  static DebtType fromKey(String key) {
    return DebtType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => DebtType.debt,
    );
  }
}

class DebtModel {
  final String id;
  final String userId;
  final String personName;
  final double amount;
  final DebtType type;
  final DateTime debtDate;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final bool isPaid;
  final String? notes;
  final DateTime createdAt;
  final bool isSynced;

  DebtModel({
    required this.id,
    required this.userId,
    required this.personName,
    required this.amount,
    required this.type,
    required this.debtDate,
    this.dueDate,
    this.paidDate,
    this.isPaid = false,
    this.notes,
    required this.createdAt,
    this.isSynced = false,
  });

  factory DebtModel.create({
    required String userId,
    required String personName,
    required double amount,
    required DebtType type,
    DateTime? debtDate,
    DateTime? dueDate,
    String? notes,
  }) {
    return DebtModel(
      id: const Uuid().v4(),
      userId: userId,
      personName: personName,
      amount: amount,
      type: type,
      debtDate: debtDate ?? DateTime.now(),
      dueDate: dueDate,
      isPaid: false,
      notes: notes,
      createdAt: DateTime.now(),
      isSynced: false,
    );
  }

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      personName: json['person_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: DebtType.fromKey(json['type'] as String),
      debtDate: DateTime.parse(json['debt_date'] as String),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date'] as String) : null,
      isPaid: json['is_paid'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: json['is_synced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'person_name': personName,
      'amount': amount,
      'type': type.key,
      'debt_date': debtDate.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'paid_date': paidDate?.toIso8601String().split('T')[0],
      'is_paid': isPaid,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalJson() {
    return {
      ...toJson(),
      'is_paid': isPaid ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory DebtModel.fromLocalJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      personName: json['person_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: DebtType.fromKey(json['type'] as String),
      debtDate: DateTime.parse(json['debt_date'] as String),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date'] as String) : null,
      isPaid: (json['is_paid'] as int?) == 1,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: (json['is_synced'] as int?) == 1,
    );
  }

  DebtModel copyWith({
    String? id,
    String? userId,
    String? personName,
    double? amount,
    DebtType? type,
    DateTime? debtDate,
    DateTime? dueDate,
    DateTime? paidDate,
    bool? isPaid,
    String? notes,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return DebtModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      debtDate: debtDate ?? this.debtDate,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
