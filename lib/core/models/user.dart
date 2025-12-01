import 'package:equatable/equatable.dart';

enum UserRole { client, owner, admin }

class User extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final bool isVerified;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.isVerified = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, fullName, email, phone, role, isVerified, createdAt];
}

