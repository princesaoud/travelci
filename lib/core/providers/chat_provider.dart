import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/models/message.dart';
import 'package:travelci/core/services/chat_service.dart';

class ChatState {
  final List<Conversation> conversations;
  final Map<String, List<Message>> messages; // conversationId -> messages
  final bool isLoading;
  final String? error;
  final Map<String, PaginationInfo?> pagination; // conversationId -> pagination

  const ChatState({
    this.conversations = const [],
    this.messages = const {},
    this.isLoading = false,
    this.error,
    this.pagination = const {},
  });

  ChatState copyWith({
    List<Conversation>? conversations,
    Map<String, List<Message>>? messages,
    bool? isLoading,
    String? error,
    Map<String, PaginationInfo?>? pagination,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pagination: pagination ?? this.pagination,
    );
  }

  List<Message> getMessagesForConversation(String conversationId) {
    return messages[conversationId] ?? [];
  }

  bool hasMoreMessages(String conversationId) {
    final paginationInfo = pagination[conversationId];
    if (paginationInfo == null) return false;
    return paginationInfo.hasNextPage;
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;

  ChatNotifier(this._chatService) : super(ChatState()) {
    // Optionally load conversations on init
  }

  /// Load conversations
  Future<void> loadConversations({String? role}) async {
    print('[ChatProvider] Loading conversations with role: $role');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final conversations = await _chatService.getConversations(role: role);
      print('[ChatProvider] Loaded ${conversations.length} conversations');
      if (conversations.isNotEmpty) {
        print('[ChatProvider] First conversation: ${conversations.first.id}, client_id: ${conversations.first.clientId}, owner_id: ${conversations.first.ownerId}');
      }
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      print('[ChatProvider] Error loading conversations: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Load messages for a conversation
  Future<void> loadMessages({
    required String conversationId,
    bool loadMore = false,
  }) async {
    try {
      final currentMessages = state.messages[conversationId] ?? [];
      final currentPage = state.pagination[conversationId]?.page ?? 1;
      
      final page = loadMore ? currentPage + 1 : 1;
      
      final response = await _chatService.getMessages(
        conversationId: conversationId,
        page: page,
        limit: 50,
      );

      final updatedMessages = Map<String, List<Message>>.from(state.messages);
      final updatedPagination = Map<String, PaginationInfo?>.from(state.pagination);

      if (loadMore) {
        // Append messages for pagination
        updatedMessages[conversationId] = [
          ...response.messages,
          ...currentMessages,
        ];
      } else {
        // Replace messages (new load)
        updatedMessages[conversationId] = response.messages;
      }

      updatedPagination[conversationId] = response.pagination;

      state = state.copyWith(
        messages: updatedMessages,
        pagination: updatedPagination,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Send a message
  Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      final message = await _chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      // Add message to local state
      final updatedMessages = Map<String, List<Message>>.from(state.messages);
      final conversationMessages = updatedMessages[conversationId] ?? [];
      updatedMessages[conversationId] = [...conversationMessages, message];

      state = state.copyWith(messages: updatedMessages);

      // Update conversation's last message
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == conversationId) {
          return conv.copyWith(
            lastMessage: message,
            lastMessageAt: message.createdAt,
          );
        }
        return conv;
      }).toList();

      state = state.copyWith(conversations: updatedConversations);

      return message;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _chatService.markMessageAsRead(messageId);

      // Update local state
      final updatedMessages = Map<String, List<Message>>.from(state.messages);
      updatedMessages.forEach((conversationId, messages) {
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          updatedMessages[conversationId] = [
            ...messages.sublist(0, index),
            messages[index].copyWith(isRead: true),
            ...messages.sublist(index + 1),
          ];
        }
      });

      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Create a conversation
  Future<Conversation?> createConversation(String bookingId) async {
    try {
      final conversation = await _chatService.createConversation(bookingId);
      
      // Add to conversations list
      final updatedConversations = [conversation, ...state.conversations];
      state = state.copyWith(conversations: updatedConversations);

      return conversation;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Refresh conversations
  Future<void> refreshConversations({String? role}) async {
    print('[ChatProvider] Refreshing conversations with role: $role');
    await loadConversations(role: role);
  }

  /// Add message to local state (for real-time updates)
  void addMessageToConversation(String conversationId, Message message) {
    final updatedMessages = Map<String, List<Message>>.from(state.messages);
    final conversationMessages = updatedMessages[conversationId] ?? [];
    
    // Check if message already exists
    if (!conversationMessages.any((m) => m.id == message.id)) {
      updatedMessages[conversationId] = [...conversationMessages, message];
      
      state = state.copyWith(messages: updatedMessages);

      // Update conversation's last message
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == conversationId) {
          return conv.copyWith(
            lastMessage: message,
            lastMessageAt: message.createdAt,
          );
        }
        return conv;
      }).toList();

      state = state.copyWith(conversations: updatedConversations);
    }
  }
}

// Provider for ChatService
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// Provider for ChatNotifier
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ChatNotifier(chatService);
});

