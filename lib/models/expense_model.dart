import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';

/// Expense Categories
enum ExpenseCategory {
  food('طعام', 'food', Iconsax.coffee),
  transport('مواصلات', 'transport', Iconsax.car),
  entertainment('ترفيه', 'entertainment', Iconsax.game),
  shopping('تسوق', 'shopping', Iconsax.shopping_bag),
  bills('فواتير', 'bills', Iconsax.bill),
  health('صحة', 'health', Iconsax.health),
  education('تعليم', 'education', Iconsax.book),
  other('أخرى', 'other', Iconsax.category);

  final String arabicName;
  final String key;
  final IconData icon;
  
  const ExpenseCategory(this.arabicName, this.key, this.icon);

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
  final String? customCategoryId; 
  // Denormalized Custom Category Fields
  final String? customCategoryName;
  final String? customCategoryIcon;
  final int? customCategoryColor;
  
  final double amount;
  final String? notes;
  final DateTime expenseDate;
  final DateTime createdAt;
  final bool isSynced;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.category,
    this.customCategoryId,
    this.customCategoryName,
    this.customCategoryIcon,
    this.customCategoryColor,
    required this.amount,
    this.notes,
    required this.expenseDate,
    required this.createdAt,
    this.isSynced = false,
  });

  // Display Getters
  String get displayName => customCategoryName ?? category.arabicName;
  
  IconData get displayIcon {
    if (customCategoryId != null && customCategoryIcon != null) {
      return getIconFromName(customCategoryIcon!) ?? category.icon;
    }
    return category.icon;
  }
  
  Color? get displayColor {
    if (customCategoryId != null && customCategoryColor != null) {
      return Color(customCategoryColor!);
    }
    return null; // Should fall back to theme colors map in UI if null
  }

  factory ExpenseModel.create({
    required String userId,
    required ExpenseCategory category,
    String? customCategoryId,
    String? customCategoryName,
    String? customCategoryIcon,
    int? customCategoryColor,
    required double amount,
    String? notes,
    DateTime? expenseDate,
  }) {
    return ExpenseModel(
      id: const Uuid().v4(),
      userId: userId,
      category: category,
      customCategoryId: customCategoryId,
      customCategoryName: customCategoryName,
      customCategoryIcon: customCategoryIcon,
      customCategoryColor: customCategoryColor,
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
      customCategoryId: json['custom_category_id'] as String?,
      customCategoryName: json['custom_category_name'] as String?,
      customCategoryIcon: json['custom_category_icon'] as String?,
      customCategoryColor: json['custom_category_color'] as int?,
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
      'custom_category_id': customCategoryId,
      'custom_category_name': customCategoryName,
      'custom_category_icon': customCategoryIcon,
      'custom_category_color': customCategoryColor,
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
      customCategoryId: json['custom_category_id'] as String?,
      customCategoryName: json['custom_category_name'] as String?,
      customCategoryIcon: json['custom_category_icon'] as String?,
      customCategoryColor: json['custom_category_color'] as int?,
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
    String? customCategoryId,
    String? customCategoryName,
    String? customCategoryIcon,
    int? customCategoryColor,
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
      customCategoryId: customCategoryId ?? this.customCategoryId,
      customCategoryName: customCategoryName ?? this.customCategoryName,
      customCategoryIcon: customCategoryIcon ?? this.customCategoryIcon,
      customCategoryColor: customCategoryColor ?? this.customCategoryColor,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
  
  static IconData? getIconFromName(String iconName) {
    switch (iconName) {
      case 'money': return Iconsax.money;
      case 'card': return Iconsax.card;
      case 'shopping_cart': return Iconsax.shopping_cart;
      case 'bag_2': return Iconsax.bag_2;
      case 'coffee': return Iconsax.coffee;
      case 'cake': return Iconsax.cake;
      case 'gift': return Iconsax.gift;
      case 'home': return Iconsax.home;
      case 'car': return Iconsax.car;
      case 'airplane': return Iconsax.airplane;
      case 'heart': return Iconsax.heart;
      case 'health': return Iconsax.health;
      case 'book': return Iconsax.book;
      case 'music': return Iconsax.music;
      case 'game': return Iconsax.game;
      case 'pet': return Iconsax.pet;
      case 'mobile': return Iconsax.mobile;
      case 'wifi': return Iconsax.wifi;
      case 'flash': return Iconsax.flash;
      case 'lamp': return Iconsax.lamp;
      case 'brush': return Iconsax.brush;
      case 'scissor': return Iconsax.scissor;
      case 'weight': return Iconsax.weight;
      case 'medal': return Iconsax.medal;
      case 'crown': return Iconsax.crown;
      case 'emoji_happy': return Iconsax.emoji_happy;
      case 'emoji_sad': return Iconsax.emoji_sad;
      case 'shopping_bag': return Iconsax.shopping_bag;
      case 'ticket': return Iconsax.ticket;
      case 'cup': return Iconsax.cup;
      default: return null;
    }
  }
}
