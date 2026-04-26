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
  final String? propertyId; // Optional - not always in API response
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  
  // Relations (optional, populated from API)
  final User? client;
  final User? owner;
  final Message? lastMessage;
  final int? unreadCount;
  final String? propertyTitle; // Title of the property for this conversation
  final DateTime? bookingStartDate; // Start date of the booking

  const Conversation({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.ownerId,
    this.propertyId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.client,
    this.owner,
    this.lastMessage,
    this.unreadCount,
    this.propertyTitle,
    this.bookingStartDate,
  });

  static String? _extractPropertyTitle(Map<String, dynamic> json) {
    if (json['property_title'] != null) {
      return json['property_title'] as String?;
    }

    if (json['booking'] != null) {
      final booking = json['booking'] as Map<String, dynamic>?;
      if (booking != null && booking['property'] != null) {
        final property = booking['property'];
        if (property is Map<String, dynamic> && property['title'] != null) {
          return property['title'] as String;
        } else if (property is List && property.isNotEmpty) {
          final firstProperty = property[0] as Map<String, dynamic>?;
          if (firstProperty != null && firstProperty['title'] != null) {
            return firstProperty['title'] as String;
          }
        }
      }
    }

    return null;
  }

  static User? _tryParseUser(dynamic userData) {
    try {
      if (userData is Map<String, dynamic>) {
        if (userData['id'] != null &&
            (userData['full_name'] != null || userData['fullName'] != null) &&
            userData['email'] != null) {
          return User.fromJson(userData);
        }
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    try {
      // property_id might not be in the response (not in conversations table schema)
      // Try to get it from booking relation if available
      String? propertyId = json['property_id'] as String?;
      
      if (propertyId == null && json['booking'] != null) {
        final booking = json['booking'] as Map<String, dynamic>?;
        if (booking != null) {
          propertyId = booking['property_id'] as String?;
        }
      }

      // Safely parse required fields with null checks
      final id = json['id'] as String?;
      final bookingId = json['booking_id'] as String?;
      final clientId = json['client_id'] as String?;
      final ownerId = json['owner_id'] as String?;
      final createdAtStr = json['created_at'] as String?;
      final updatedAtStr = json['updated_at'] as String?;

      if (id == null) {
        throw Exception('Conversation id is null');
      }
      if (bookingId == null) {
        throw Exception('Conversation booking_id is null');
      }
      if (clientId == null) {
        throw Exception('Conversation client_id is null');
      }
      if (ownerId == null) {
        throw Exception('Conversation owner_id is null');
      }
      if (createdAtStr == null) {
        throw Exception('Conversation created_at is null');
      }
      if (updatedAtStr == null) {
        throw Exception('Conversation updated_at is null');
      }

      return Conversation(
        id: id,
        bookingId: bookingId,
        clientId: clientId,
        ownerId: ownerId,
        propertyId: propertyId,
        createdAt: DateTime.parse(createdAtStr),
        updatedAt: DateTime.parse(updatedAtStr),
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
        client: json['client'] != null
            ? _tryParseUser(json['client'])
            : null,
        owner: json['owner'] != null
            ? _tryParseUser(json['owner'])
            : null,
        lastMessage: json['last_message'] != null
            ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: json['unread_count'] as int?,
        propertyTitle: _extractPropertyTitle(json),
        bookingStartDate: json['booking_start_date'] != null
            ? DateTime.parse(json['booking_start_date'] as String)
            : null,
      );
    } catch (e) {
      rethrow;
    }
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
      if (propertyTitle != null) 'property_title': propertyTitle,
      if (bookingStartDate != null) 'booking_start_date': bookingStartDate!.toIso8601String(),
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
    String? propertyTitle,
    DateTime? bookingStartDate,
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
      propertyTitle: propertyTitle ?? this.propertyTitle,
      bookingStartDate: bookingStartDate ?? this.bookingStartDate,
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
        propertyTitle,
        bookingStartDate,
      ];
}

