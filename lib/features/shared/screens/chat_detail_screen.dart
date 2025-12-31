import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; // For MissingPluginException
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUploadingFile = false;
  String? _selectedFilePath;
  String? _selectedFileName;
  Timer? _messagePollingTimer;
  bool _isScreenActive = true;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set this conversation as active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).setActiveConversation(widget.conversation.id);
    });

    // Load messages when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMessages();
      // Initialize message count after first load
      if (mounted) {
        final chatState = ref.read(chatProvider);
        final messages = chatState.getMessagesForConversation(widget.conversation.id);
        _previousMessageCount = messages.length;
      }
    });

    // Start polling for new messages every 3 seconds
    _startMessagePolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagePollingTimer?.cancel();
    // Clear active conversation when leaving
    ref.read(chatProvider.notifier).setActiveConversation(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause polling when app goes to background, resume when it comes back
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isScreenActive = false;
      _messagePollingTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isScreenActive = true;
      _loadMessages(); // Immediately load messages when app resumes
      _startMessagePolling();
    }
  }

  void _loadMessages() async {
    if (!mounted) return;
    await ref.read(chatProvider.notifier).loadMessages(
      conversationId: widget.conversation.id,
    );
    
    // Check if new messages arrived and auto-scroll if user is near bottom
    if (mounted) {
      final chatState = ref.read(chatProvider);
      final currentMessages = chatState.getMessagesForConversation(widget.conversation.id);
      final currentMessageCount = currentMessages.length;
      
      // If new messages arrived and user is near bottom, scroll to bottom
      if (currentMessageCount > _previousMessageCount && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        // If user is within 100px of bottom, auto-scroll
        if (maxScroll - currentScroll < 100) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
      
      _previousMessageCount = currentMessageCount;
    }
  }

  void _startMessagePolling() {
    _messagePollingTimer?.cancel();
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isScreenActive && mounted && !_isSending && !_isUploadingFile) {
        _loadMessages();
      }
    });
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

  String _getConversationTitle() {
    final propertyTitle = widget.conversation.propertyTitle ?? 'Appartement';
    // Use conversation createdAt as the booking request date (date de demande)
    final requestDate = DateFormat('dd/MM/yyyy').format(widget.conversation.createdAt);
    // Include booking ID (first 8 characters) to make it unique
    final bookingIdShort = widget.conversation.bookingId.length > 8 
        ? widget.conversation.bookingId.substring(0, 8) 
        : widget.conversation.bookingId;
    return '$propertyTitle le $requestDate - Res. $bookingIdShort';
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

  bool _isImageFile(String? fileName) {
    if (fileName == null) return false;
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  void _previewImage(BuildContext context, String imageUrl, String? fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              fileName ?? 'Image',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      // Ensure we're on a supported platform
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La sélection de fichiers depuis le navigateur n\'est pas encore supportée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Use FilePicker with proper error handling
      FilePickerResult? result;
      
      try {
        // Add a small delay to ensure plugin is initialized
        await Future.delayed(const Duration(milliseconds: 100));
        
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
      } on MissingPluginException catch (e) {
        // Handle MissingPluginException specifically
        print('[ChatDetailScreen] FilePicker MissingPluginException: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le plugin de sélection de fichiers n\'est pas initialisé. Veuillez arrêter complètement l\'application et la redémarrer (pas juste un hot reload).',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      } on PlatformException catch (e) {
        // Handle platform-specific exceptions
        print('[ChatDetailScreen] FilePicker PlatformException: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de plateforme: ${e.message ?? e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      } on Exception catch (e) {
        // Handle other exceptions
        print('[ChatDetailScreen] FilePicker exception: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ouverture du sélecteur de fichiers: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      } catch (e) {
        // Handle any other errors including LateInitializationError
        print('[ChatDetailScreen] FilePicker error: $e');
        print('[ChatDetailScreen] Error type: ${e.runtimeType}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur d\'initialisation du sélecteur de fichiers. Veuillez redémarrer l\'application et réessayer.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check if we have a file path (mobile platforms)
        if (file.path != null && file.path!.isNotEmpty) {
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'obtenir le chemin du fichier sélectionné'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
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
      // Log the error for debugging
      print('[ChatDetailScreen] File picker error: $e');
      print('[ChatDetailScreen] Error type: ${e.runtimeType}');
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
      print('[ChatDetailScreen] Starting file upload: ${_selectedFilePath}, name: ${_selectedFileName}');
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

        print('[ChatDetailScreen] File upload successful: $fileInfo');
        fileUrl = fileInfo['file_url'] as String?;
        fileName = fileInfo['file_name'] as String?;
        fileSize = fileInfo['file_size'] as int?;

        print('[ChatDetailScreen] Extracted file info - url: $fileUrl, name: $fileName, size: $fileSize');

        if (fileUrl == null || fileName == null) {
          throw Exception('Les informations du fichier sont incomplètes après l\'upload');
        }

        setState(() {
          _selectedFilePath = null;
          _selectedFileName = null;
          _isUploadingFile = false;
        });
      } catch (e) {
        print('[ChatDetailScreen] File upload error: $e');
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

    print('[ChatDetailScreen] Sending message - content: "$messageContent", hasFile: ${fileUrl != null}, fileUrl: $fileUrl, fileName: $fileName, fileSize: $fileSize');

    _messageController.clear();

    try {
      await ref.read(chatProvider.notifier).sendMessage(
        conversationId: widget.conversation.id,
        content: messageContent,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      // Update message count after sending
      if (mounted) {
        final chatState = ref.read(chatProvider);
        final messages = chatState.getMessagesForConversation(widget.conversation.id);
        _previousMessageCount = messages.length;
      }

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
              _getConversationTitle(),
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
                                  if (_isImageFile(message.fileName))
                                    // Image preview
                                    GestureDetector(
                                      onTap: () {
                                        _previewImage(context, message.fileUrl!, message.fileName);
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxHeight: 300,
                                          maxWidth: 250,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isMe 
                                                ? Colors.white.withOpacity(0.3)
                                                : Colors.grey[400]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Stack(
                                            children: [
                                              CachedNetworkImage(
                                                imageUrl: message.fileUrl!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                placeholder: (context, url) => Container(
                                                  height: 200,
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  height: 200,
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(Icons.error),
                                                  ),
                                                ),
                                              ),
                                              // Overlay with file info
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter,
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.black.withOpacity(0.7),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              message.fileName ?? 'Image',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            if (message.fileSize != null)
                                                              Text(
                                                                _formatFileSize(message.fileSize!),
                                                                style: TextStyle(
                                                                  color: Colors.white70,
                                                                  fontSize: 10,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const Icon(
                                                        FontAwesomeIcons.expand,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    // Non-image file
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

