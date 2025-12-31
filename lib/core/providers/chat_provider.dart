import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/models/message.dart';
import 'package:travelci/core/services/chat_service.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/providers/auth_provider.dart';

class ChatState {
  final List<Conversation> conversations;
  final Map<String, List<Message>> messages; // conversationId -> messages
  final bool isLoading;
  final String? error;
  final Map<String, PaginationInfo?> pagination; // conversationId -> pagination
  final String? activeConversationId; // Currently open conversation ID

  const ChatState({
    this.conversations = const [],
    this.messages = const {},
    this.isLoading = false,
    this.error,
    this.pagination = const {},
    this.activeConversationId,
  });

  ChatState copyWith({
    List<Conversation>? conversations,
    Map<String, List<Message>>? messages,
    bool? isLoading,
    String? error,
    Map<String, PaginationInfo?>? pagination,
    String? activeConversationId,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pagination: pagination ?? this.pagination,
      activeConversationId: activeConversationId ?? this.activeConversationId,
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
  final Ref _ref;
  final Set<String> _notifiedMessageIds = {}; // Track already notified messages

  ChatNotifier(this._chatService, this._ref) : super(ChatState()) {
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
      
      // Sort conversations by lastMessageAt descending (most recent first)
      final sortedConversations = List<Conversation>.from(conversations);
      sortedConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      
      // Debug: Log conversation details
      print('[ChatProvider] Final conversations count: ${sortedConversations.length}');
      for (var conv in sortedConversations) {
        print('[ChatProvider] Conversation ${conv.id}: client=${conv.client != null ? conv.client!.fullName : "null"}, owner=${conv.owner != null ? conv.owner!.fullName : "null"}');
      }
      
      state = state.copyWith(
        conversations: sortedConversations,
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

  /// Set active conversation (currently open)
  void setActiveConversation(String? conversationId) {
    state = state.copyWith(activeConversationId: conversationId);
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

      // Track previous message IDs to detect new ones
      final previousMessageIds = currentMessages.map((m) => m.id).toSet();

      if (loadMore) {
        // Append messages for pagination
        updatedMessages[conversationId] = [
          ...response.messages,
          ...currentMessages,
        ];
      } else {
        // Replace messages (new load)
        updatedMessages[conversationId] = response.messages;
        
        // Detect new messages and send notifications
        final currentUserId = _ref.read(authProvider).user?.id;
        if (currentUserId != null) {
          final newMessages = response.messages.where((msg) {
            // Only notify for messages not sent by current user
            // and that weren't in the previous list
            return msg.senderId != currentUserId &&
                   !previousMessageIds.contains(msg.id) &&
                   msg.messageType != 'system';
          }).toList();

          // Send notifications for new messages
          if (newMessages.isNotEmpty) {
            _notifyNewMessages(conversationId, newMessages, currentUserId);
          }
        }
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

  /// Notify about new messages
  Future<void> _notifyNewMessages(
    String conversationId,
    List<Message> newMessages,
    String currentUserId,
  ) async {
    // Don't notify if user is currently viewing this conversation
    if (state.activeConversationId == conversationId) {
      return;
    }

    // Find conversation details
    final conversation = state.conversations.firstWhere(
      (conv) => conv.id == conversationId,
      orElse: () => Conversation(
        id: conversationId,
        bookingId: '',
        clientId: '',
        ownerId: '',
        createdAt: DateTime.now(),
      ),
    );

    // Get notification provider
    final notificationNotifier = _ref.read(notificationProvider.notifier);

    // Filter messages: only notify for messages created in the last 5 minutes
    // This prevents notifying old messages when opening a conversation for the first time
    final now = DateTime.now();
    final recentMessages = newMessages.where((message) {
      final messageAge = now.difference(message.createdAt);
      return messageAge.inMinutes < 5; // Only messages from last 5 minutes
    }).toList();

    // Notify for each new message (only once per message)
    for (final message in recentMessages) {
      if (_notifiedMessageIds.contains(message.id)) {
        continue; // Already notified
      }

      // Get sender name
      final senderName = message.sender?.fullName ?? 'Utilisateur';
      
      // Get property title from conversation
      final propertyTitle = conversation.propertyTitle;

      // Send notification
      await notificationNotifier.notifyNewMessage(
        messageId: message.id,
        conversationId: conversationId,
        senderName: senderName,
        messageContent: message.content,
        propertyTitle: propertyTitle,
        bookingId: conversation.bookingId,
      );

      // Mark as notified
      _notifiedMessageIds.add(message.id);
    }

    // Clean up old notified message IDs (keep only last 100)
    if (_notifiedMessageIds.length > 100) {
      final idsToRemove = _notifiedMessageIds.take(_notifiedMessageIds.length - 100).toList();
      for (final id in idsToRemove) {
        _notifiedMessageIds.remove(id);
      }
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

      // Update conversation's last message and sort by lastMessageAt
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == conversationId) {
          return conv.copyWith(
            lastMessage: message,
            lastMessageAt: message.createdAt,
          );
        }
        return conv;
      }).toList();

      // Sort conversations by lastMessageAt descending (most recent first)
      updatedConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

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

      // Update conversation's last message and sort by lastMessageAt
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == conversationId) {
          return conv.copyWith(
            lastMessage: message,
            lastMessageAt: message.createdAt,
          );
        }
        return conv;
      }).toList();

      // Sort conversations by lastMessageAt descending (most recent first)
      updatedConversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

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
  return ChatNotifier(chatService, ref);
});

