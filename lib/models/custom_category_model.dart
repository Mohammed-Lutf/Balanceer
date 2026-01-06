import 'package:uuid/uuid.dart';

/// Custom Category Model for user-defined expense categories
class CustomCategoryModel {
  final String id;
  final String userId;
  final String name;
  final String iconName; // Icon name from Iconsax
  final int colorValue; // Color as int for storage
  final DateTime createdAt;
  final bool isSynced;

  CustomCategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconName,
    required this.colorValue,
    required this.createdAt,
    this.isSynced = false,
  });

  /// Create a new custom category
  factory CustomCategoryModel.create({
    required String userId,
    required String name,
    required String iconName,
    required int colorValue,
  }) {
    return CustomCategoryModel(
      id: const Uuid().v4(),
      userId: userId,
      name: name,
      iconName: iconName,
      colorValue: colorValue,
      createdAt: DateTime.now(),
      isSynced: false,
    );
  }

  /// Create from Supabase JSON
  factory CustomCategoryModel.fromJson(Map<String, dynamic> json) {
    return CustomCategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String,
      colorValue: json['color_value'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: true,
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'icon_name': iconName,
      'color_value': colorValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from local SQLite JSON
  factory CustomCategoryModel.fromLocalJson(Map<String, dynamic> json) {
    return CustomCategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String,
      colorValue: json['color_value'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: (json['is_synced'] as int?) == 1,
    );
  }

  /// Convert to local SQLite JSON
  Map<String, dynamic> toLocalJson() {
    return {
      ...toJson(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Copy with modifications
  CustomCategoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? iconName,
    int? colorValue,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return CustomCategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() => 'CustomCategory(name: $name, icon: $iconName)';
}

/// Available icons for custom categories
class CategoryIcons {
  static const List<String> availableIcons = [
    'money',
    'card',
    'shopping_cart',
    'bag_2',
    'coffee',
    'cake',
    'gift',
    'home',
    'car',
    'airplane',
    'heart',
    'health',
    'book',
    'music',
    'game',
    'pet',
    'mobile',
    'wifi',
    'flash',
    'lamp',
    'brush',
    'scissor',
    'weight',
    'medal',
    'crown',
    'emoji_happy',
    'emoji_sad',
    'shopping_bag',
    'ticket',
    'cup',
  ];
}

/// Available colors for custom categories
class CategoryColors {
  static const List<int> availableColors = [
    0xFFFF6B6B, // Red
    0xFFFF8E53, // Orange
    0xFFF59E0B, // Amber
    0xFFFFD93D, // Yellow
    0xFF10B981, // Emerald
    0xFF00D9A5, // Teal
    0xFF4ECDC4, // Cyan
    0xFF3B82F6, // Blue
    0xFF6366F1, // Indigo
    0xFFA78BFA, // Violet
    0xFFEC4899, // Pink
    0xFFD946EF, // Fuchsia
    0xFF8B5CF6, // Purple
    0xFF6B7280, // Gray
  ];
}
