import 'package:uuid/uuid.dart';

/// User Model
class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final bool isOfflineCreated;

  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
    this.isOfflineCreated = false,
  });

  factory UserModel.create({
    required String email,
    String? displayName,
    bool isOffline = false,
  }) {
    return UserModel(
      id: const Uuid().v4(),
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      isOfflineCreated: isOffline,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isOfflineCreated: json['is_offline_created'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'is_offline_created': isOfflineCreated,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    DateTime? createdAt,
    bool? isOfflineCreated,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      isOfflineCreated: isOfflineCreated ?? this.isOfflineCreated,
    );
  }
}
