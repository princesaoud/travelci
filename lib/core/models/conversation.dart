import 'package:equatable/equatable.dart';
import 'package:travelci/core/models/message.dart';
import 'package:travelci/core/models/user.dart';

/// Conversation Model
/// 
/// Represents a chat conversation between a client and an owner
class Conversation extends Equatable {
  final String id;
  final String bookingId;
  final String clientId;
  final String ownerId;
  final String propertyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  
  // Relations (optional, populated from API)
  final User? client;
  final User? owner;
  final Message? lastMessage;
  final int? unreadCount;

  const Conversation({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.ownerId,
    required this.propertyId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.client,
    this.owner,
    this.lastMessage,
    this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      clientId: json['client_id'] as String,
      ownerId: json['owner_id'] as String,
      propertyId: json['property_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      client: json['client'] != null
          ? User.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      owner: json['owner'] != null
          ? User.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'client_id': clientId,
      'owner_id': ownerId,
      'property_id': propertyId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (lastMessageAt != null) 'last_message_at': lastMessageAt!.toIso8601String(),
      if (client != null) 'client': client!.toJson(),
      if (owner != null) 'owner': owner!.toJson(),
      if (lastMessage != null) 'last_message': lastMessage!.toJson(),
      if (unreadCount != null) 'unread_count': unreadCount,
    };
  }

  Conversation copyWith({
    String? id,
    String? bookingId,
    String? clientId,
    String? ownerId,
    String? propertyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    User? client,
    User? owner,
    Message? lastMessage,
    int? unreadCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      clientId: clientId ?? this.clientId,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      client: client ?? this.client,
      owner: owner ?? this.owner,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookingId,
        clientId,
        ownerId,
        propertyId,
        createdAt,
        updatedAt,
        lastMessageAt,
        client,
        owner,
        lastMessage,
        unreadCount,
      ];
}

