import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/chat_provider.dart';
import 'package:travelci/core/services/chat_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final Conversation conversation;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUploadingFile = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    
    // Load messages when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadMessages(
        conversationId: widget.conversation.id,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  User? _getOtherUser(User currentUser) {
    if (currentUser.role == UserRole.client) {
      return widget.conversation.owner;
    } else {
      return widget.conversation.client;
    }
  }

  String _getCurrentUserId() {
    final user = ref.read(authProvider).user;
    return user?.id ?? '';
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Hier ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return FontAwesomeIcons.filePdf;
      case 'doc':
      case 'docx':
        return FontAwesomeIcons.fileWord;
      case 'xls':
      case 'xlsx':
        return FontAwesomeIcons.fileExcel;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return FontAwesomeIcons.fileImage;
      case 'mp4':
      case 'avi':
      case 'mov':
        return FontAwesomeIcons.fileVideo;
      case 'mp3':
      case 'wav':
        return FontAwesomeIcons.fileAudio;
      case 'zip':
      case 'rar':
        return FontAwesomeIcons.fileZipper;
      default:
        return FontAwesomeIcons.file;
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection du fichier: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if ((content.isEmpty && _selectedFilePath == null) || _isSending || _isUploadingFile) return;

    setState(() {
      _isSending = true;
    });

    String? fileUrl;
    String? fileName;
    int? fileSize;

    // Upload file if selected
    if (_selectedFilePath != null) {
      setState(() {
        _isUploadingFile = true;
      });

      try {
        final chatService = ChatService();
        final fileInfo = await chatService.uploadFile(
          conversationId: widget.conversation.id,
          filePath: _selectedFilePath!,
          fileName: _selectedFileName ?? 'file',
        );

        fileUrl = fileInfo['file_url'] as String;
        fileName = fileInfo['file_name'] as String;
        fileSize = fileInfo['file_size'] as int;

        setState(() {
          _selectedFilePath = null;
          _selectedFileName = null;
          _isUploadingFile = false;
        });
      } catch (e) {
        setState(() {
          _isUploadingFile = false;
          _isSending = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du téléchargement du fichier: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final messageContent = content.isEmpty && fileUrl != null 
        ? fileName ?? 'Fichier joint' 
        : content;

    _messageController.clear();

    try {
      await ref.read(chatProvider.notifier).sendMessage(
        conversationId: widget.conversation.id,
        content: messageContent,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du message: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final otherUser = _getOtherUser(user);
    final messages = chatState.getMessagesForConversation(widget.conversation.id);
    final currentUserId = _getCurrentUserId();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.propertyTitle ?? 'Réservation',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              otherUser?.fullName ?? 'Chat',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(chatProvider.notifier).loadMessages(
                  conversationId: widget.conversation.id,
                );
              },
              child: messages.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FontAwesomeIcons.comments,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Aucun message',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: false,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUserId;
                        final isSystemMessage = message.messageType == 'system';

                        // System messages are centered and styled differently
                        if (isSystemMessage) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.circleInfo,
                                    size: 14,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      message.content,
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // File attachment
                                if (message.fileUrl != null) ...[
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await OpenFilex.open(message.fileUrl!);
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Impossible d\'ouvrir le fichier: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe 
                                            ? Colors.white.withOpacity(0.2)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getFileIcon(message.fileName ?? 'file'),
                                            color: isMe ? Colors.white : Colors.blue,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message.fileName ?? 'Fichier',
                                                  style: TextStyle(
                                                    color: isMe ? Colors.white : Colors.black87,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (message.fileSize != null)
                                                  Text(
                                                    _formatFileSize(message.fileSize!),
                                                    style: TextStyle(
                                                      color: isMe ? Colors.white70 : Colors.black54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            FontAwesomeIcons.download,
                                            color: isMe ? Colors.white70 : Colors.black54,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (message.content.isNotEmpty) const SizedBox(height: 8),
                                ],
                                // Message content
                                if (message.content.isNotEmpty)
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatMessageTime(message.createdAt),
                                      style: TextStyle(
                                        color: isMe ? Colors.white70 : Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        message.isRead
                                            ? FontAwesomeIcons.checkDouble
                                            : FontAwesomeIcons.check,
                                        size: 12,
                                        color: message.isRead
                                            ? Colors.blue[200]
                                            : Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selected file indicator
                  if (_selectedFilePath != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(_selectedFileName ?? 'file'),
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFileName ?? 'Fichier',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedFilePath = null;
                                _selectedFileName = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  // Uploading indicator
                  if (_isUploadingFile)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Téléchargement du fichier...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Input row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.paperclip),
                        onPressed: (_isSending || _isUploadingFile) ? null : _pickFile,
                        tooltip: 'Joindre un fichier',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: _selectedFilePath != null 
                                ? 'Ajouter un message (optionnel)...'
                                : 'Tapez un message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isSending && !_isUploadingFile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: (_isSending || _isUploadingFile)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(FontAwesomeIcons.paperPlane),
                        onPressed: (_isSending || _isUploadingFile) ? null : _sendMessage,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

