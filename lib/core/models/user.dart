import 'package:equatable/equatable.dart';

enum UserRole { client, owner, admin }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.client:
        return 'client';
      case UserRole.owner:
        return 'owner';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'client':
        return UserRole.client;
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.client;
    }
  }
}

class User extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] != null
          ? UserRoleExtension.fromString(json['role'] as String)
          : UserRole.client,
      isVerified: json['is_verified'] as bool? ?? json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
      updatedAt: json['updated_at'] != null || json['updatedAt'] != null
          ? DateTime.parse(json['updated_at'] as String? ?? json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role.value,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, fullName, email, phone, role, isVerified, createdAt, updatedAt];
}

