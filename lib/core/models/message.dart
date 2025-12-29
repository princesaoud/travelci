import 'package:equatable/equatable.dart';
import 'package:travelci/core/models/user.dart';

/// Message Model
/// 
/// Represents a chat message
class Message extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String messageType; // 'text', 'image', 'file', 'system'
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // File attachments (for file/image messages)
  final String? fileUrl;
  final String? fileName;
  final int? fileSize; // in bytes
  
  // Relations (optional, populated from API)
  final User? sender;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.isRead = false,
    required this.createdAt,
    this.updatedAt,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      sender: json['sender'] != null
          ? User.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (sender != null) 'sender': sender!.toJson(),
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? messageType,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    User? sender,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      sender: sender ?? this.sender,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        content,
        messageType,
        isRead,
        createdAt,
        updatedAt,
        fileUrl,
        fileName,
        fileSize,
        sender,
      ];
}

