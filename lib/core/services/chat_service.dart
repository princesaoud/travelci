import 'package:dio/dio.dart';
import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/models/message.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';
import 'package:travelci/core/utils/error_handler.dart';
import 'package:travelci/core/utils/token_manager.dart';

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

    print('[ChatService] Fetching conversations with params: $queryParams');
    print('[ChatService] Endpoint: ${ApiConfig.conversationsEndpoint}');

    final response = await get<Map<String, dynamic>>(
      ApiConfig.conversationsEndpoint,
      queryParameters: queryParams,
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    print('[ChatService] API Response: ${apiResponse.data}');
    print('[ChatService] API Success: ${apiResponse.success}');
    print('[ChatService] API Error: ${apiResponse.error}');

    if (apiResponse.data != null) {
      // Try different possible response formats
      List<dynamic>? conversationsData;
      
      // Format 1: data.conversations (array)
      if (apiResponse.data!['conversations'] is List) {
        conversationsData = apiResponse.data!['conversations'] as List<dynamic>;
      }
      // Format 2: data is directly an array
      else if (apiResponse.data is List) {
        conversationsData = apiResponse.data as List<dynamic>;
      }
      // Format 3: data.data.conversations (nested)
      else if (apiResponse.data!['data'] is Map && 
               (apiResponse.data!['data'] as Map<String, dynamic>)['conversations'] is List) {
        conversationsData = (apiResponse.data!['data'] as Map<String, dynamic>)['conversations'] as List<dynamic>;
      }

      if (conversationsData != null) {
        print('[ChatService] Found ${conversationsData.length} conversations');
        final conversations = conversationsData
            .map((item) {
              try {
                final conv = Conversation.fromJson(item as Map<String, dynamic>);
                print('[ChatService] Parsed conversation ${conv.id}: client=${conv.client != null}, owner=${conv.owner != null}');
                return conv;
              } catch (e) {
                print('[ChatService] Error parsing conversation: $e');
                print('[ChatService] Conversation data: $item');
                rethrow;
              }
            })
            .toList();
        return conversations;
      } else {
        print('[ChatService] No conversations found in response data');
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
      'conversation_id': conversationId,
      'page': page,
      'limit': limit,
    };

    print('[ChatService] Fetching messages for conversation: $conversationId, page: $page, limit: $limit');

    final response = await get<Map<String, dynamic>>(
      ApiConfig.messagesEndpoint,
      queryParameters: queryParams,
      parser: (data) => data as Map<String, dynamic>,
    );

    print('[ChatService] API response received: ${response.toString().substring(0, response.toString().length > 200 ? 200 : response.toString().length)}...');

    final apiResponse = ApiResponse<List<dynamic>>.fromJson(
      response,
      (data) => data as List<dynamic>,
    );

    print('[ChatService] Parsed API response - success: ${apiResponse.success}, data type: ${apiResponse.data.runtimeType}, data length: ${apiResponse.data?.length ?? 0}');

    if (apiResponse.data != null) {
      // Backend returns messages directly in data array (not in data.messages)
      final messagesData = apiResponse.data!;
      print('[ChatService] Messages data length: ${messagesData.length}');
      
      if (messagesData.isNotEmpty) {
        final messages = messagesData
            .map((item) {
              try {
                return Message.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                print('[ChatService] Error parsing message: $e, item: $item');
                rethrow;
              }
            })
            .toList();
        
        print('[ChatService] Successfully parsed ${messages.length} messages');
        
        return MessageListResponse(
          messages: messages,
          pagination: apiResponse.pagination,
        );
      } else {
        // Empty array - no messages yet
        print('[ChatService] No messages found (empty array)');
        return MessageListResponse(
          messages: [],
          pagination: apiResponse.pagination,
        );
      }
    }

    print('[ChatService] Error: ${apiResponse.error?.message ?? 'Unknown error'}');
    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer les messages');
  }

  /// Upload a file for a message
  Future<Map<String, dynamic>> uploadFile({
    required String conversationId,
    required String filePath,
    required String fileName,
  }) async {
    print('[ChatService] Starting file upload - conversationId: $conversationId, filePath: $filePath, fileName: $fileName');
    
    final token = await TokenManager.getToken();
    if (token == null) {
      throw Exception('Vous devez être connecté pour envoyer un fichier');
    }

    final file = await MultipartFile.fromFile(
      filePath,
      filename: fileName,
    );

    print('[ChatService] File created - size: ${file.length}, filename: ${file.filename}');

    final formData = FormData.fromMap({
      'file': file,
    });

    try {
      print('[ChatService] Uploading to: ${ApiConfig.conversationUploadFileEndpoint(conversationId)}');
      final response = await dio.post(
        ApiConfig.conversationUploadFileEndpoint(conversationId),
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('[ChatService] Upload response received: ${response.statusCode}');
      print('[ChatService] Upload response data: ${response.data}');

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );

      if (apiResponse.data != null) {
        final result = {
          'file_url': apiResponse.data!['file_url'] as String?,
          'file_name': apiResponse.data!['file_name'] as String?,
          'file_size': apiResponse.data!['file_size'] as int?,
        };
        print('[ChatService] Upload successful - result: $result');
        return result;
      }

      print('[ChatService] Upload failed - no data in response, error: ${apiResponse.error?.message}');
      throw Exception(apiResponse.error?.message ?? 'Erreur lors du téléchargement du fichier');
    } on DioException catch (e) {
      print('[ChatService] Upload DioException: ${e.type}, message: ${e.message}, response: ${e.response?.data}');
      throw Exception(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      print('[ChatService] Upload error: $e');
      rethrow;
    }
  }

  /// Send a message in a conversation
  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    final messageData = {
      'conversation_id': conversationId,
      'content': content,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
    };

    print('[ChatService] Sending message with data: $messageData');

    try {
      final response = await post<Map<String, dynamic>>(
        ApiConfig.messagesEndpoint,
        data: messageData,
        parser: (data) => data as Map<String, dynamic>,
      );

      print('[ChatService] Message sent successfully - response: $response');

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

      print('[ChatService] Message send failed - error: ${apiResponse.error?.message}, code: ${apiResponse.error?.code}');
      throw Exception(apiResponse.error?.message ?? 'Erreur lors de l\'envoi du message');
    } on DioException catch (e) {
      print('[ChatService] Message send DioException: ${e.type}, message: ${e.message}');
      print('[ChatService] Response data: ${e.response?.data}');
      print('[ChatService] Response status: ${e.response?.statusCode}');
      throw Exception(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      print('[ChatService] Message send error: $e');
      rethrow;
    }
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

