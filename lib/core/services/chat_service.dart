import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/models/message.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

/// Chat Service
/// 
/// Handles chat-related API calls (conversations and messages)
class ChatService extends ApiService {
  /// Get all conversations for the current user
  /// 
  /// [role] can be 'client' or 'owner' to filter conversations
  /// [page] and [limit] for pagination
  Future<List<Conversation>> getConversations({
    String? role,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (role != null) {
      queryParams['role'] = role;
    }

    final response = await get<Map<String, dynamic>>(
      ApiConfig.conversationsEndpoint,
      queryParameters: queryParams,
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final conversationsData = apiResponse.data!['conversations'] as List<dynamic>?;
      if (conversationsData != null) {
        return conversationsData
            .map((item) => Conversation.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer les conversations');
  }

  /// Get conversation by ID
  Future<Conversation> getConversationById(String id) async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.conversationEndpoint(id),
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final conversationData = apiResponse.data!['conversation'] as Map<String, dynamic>?;
      if (conversationData != null) {
        return Conversation.fromJson(conversationData);
      }
    }

    throw Exception(apiResponse.error?.message ?? 'Conversation non trouvée');
  }

  /// Create a new conversation
  Future<Conversation> createConversation(String bookingId) async {
    final response = await post<Map<String, dynamic>>(
      ApiConfig.conversationsEndpoint,
      data: {
        'booking_id': bookingId,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final conversationData = apiResponse.data!['conversation'] as Map<String, dynamic>?;
      if (conversationData != null) {
        return Conversation.fromJson(conversationData);
      }
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de la création de la conversation');
  }

  /// Get messages for a conversation
  /// 
  /// [conversationId] The conversation ID
  /// [page] and [limit] for pagination
  Future<MessageListResponse> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    final response = await get<Map<String, dynamic>>(
      ApiConfig.conversationMessagesEndpoint(conversationId),
      queryParameters: queryParams,
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final messagesData = apiResponse.data!['messages'] as List<dynamic>?;
      if (messagesData != null) {
        final messages = messagesData
            .map((item) => Message.fromJson(item as Map<String, dynamic>))
            .toList();
        
        return MessageListResponse(
          messages: messages,
          pagination: apiResponse.pagination,
        );
      }
    }

    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer les messages');
  }

  /// Send a message in a conversation
  Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConfig.conversationMessagesEndpoint(conversationId),
      data: {
        'content': content,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final messageData = apiResponse.data!['message'] as Map<String, dynamic>?;
      if (messageData != null) {
        return Message.fromJson(messageData);
      }
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de l\'envoi du message');
  }

  /// Mark a message as read
  Future<void> markMessageAsRead(String messageId) async {
    final response = await put<Map<String, dynamic>>(
      ApiConfig.messageReadEndpoint(messageId),
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (!apiResponse.success) {
      throw Exception(apiResponse.error?.message ?? 'Erreur lors du marquage du message comme lu');
    }
  }

  /// Get unread message count for a conversation
  Future<int> getUnreadCount(String conversationId) async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.conversationUnreadCountEndpoint(conversationId),
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return apiResponse.data!['unread_count'] as int? ?? 0;
    }

    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer le nombre de messages non lus');
  }
}

/// Message List Response
class MessageListResponse {
  final List<Message> messages;
  final PaginationInfo? pagination;

  MessageListResponse({
    required this.messages,
    this.pagination,
  });
}

