import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/chat_provider.dart';
import 'package:travelci/features/shared/screens/chat_detail_screen.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends ConsumerState<ConversationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Load conversations when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        print('[ConversationsList] Loading conversations for user: ${user.id}, role: ${user.role.value}');
        ref.read(chatProvider.notifier).loadConversations(
          role: user.role.value,
        );
      } else {
        print('[ConversationsList] No user found, cannot load conversations');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh conversations when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && mounted) {
        ref.read(chatProvider.notifier).refreshConversations(
          role: user.role.value,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  User? _getOtherUser(Conversation conversation, User currentUser) {
    if (currentUser.role == UserRole.client) {
      return conversation.owner;
    } else {
      return conversation.client;
    }
  }

  String _formatLastMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE', 'fr_FR').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;

    return conversations.where((conv) {
      final otherUser = _getOtherUser(conv, ref.read(authProvider).user!);
      if (otherUser == null) return false;

      return otherUser.fullName.toLowerCase().contains(_searchQuery) ||
          otherUser.email.toLowerCase().contains(_searchQuery) ||
          (conv.lastMessage?.content.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final user = ref.watch(authProvider).user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final conversations = _filterConversations(chatState.conversations);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation...',
                prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(FontAwesomeIcons.xmark),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // Conversations list
          Expanded(
            child: chatState.isLoading && conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(chatProvider.notifier).refreshConversations(
                        role: user.role.value,
                      );
                    },
                    child: conversations.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height - 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isNotEmpty
                                          ? FontAwesomeIcons.magnifyingGlass
                                          : FontAwesomeIcons.comments,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Aucune conversation trouvée'
                                          : 'Aucune conversation',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                                    ),
                                    if (!_searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Vos conversations apparaîtront ici',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = conversations[index];
                              final otherUser = _getOtherUser(conversation, user);

                              if (otherUser == null) {
                                return const SizedBox.shrink();
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: Text(
                                      otherUser.fullName[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conversation.propertyTitle ?? 'Réservation',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        otherUser.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        conversation.lastMessage?.content ?? 'Aucun message',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatLastMessageTime(conversation.lastMessageAt),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: conversation.unreadCount != null &&
                                          conversation.unreadCount! > 0
                                      ? Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${conversation.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatDetailScreen(
                                          conversation: conversation,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

