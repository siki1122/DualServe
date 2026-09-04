import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_theme.dart';
import '../../services/logging_service.dart';
import '../../utils/global_state.dart';
import 'package:household_towing_app/utils/app_theme.dart';


class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
  late final String _currentUserId;
  bool _isInitialized = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    GlobalState.activeChatBookingId.value = widget.bookingId;
    _initializeUser();
  }

  void _initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _isInitialized = true;
    } else {
      Logger.warn('Current user not found in chat screen');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    GlobalState.activeChatBookingId.value = null;
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage({String? imageUrl}) {
    if (_controller.text.trim().isEmpty && imageUrl == null) return;

    final message = Message(
      id: '',
      bookingId: widget.bookingId,
      senderId: _currentUserId,
      receiverId: widget.receiverId,
      text: _controller.text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
      imageUrl: imageUrl,
    );

    _chatService.sendMessage(message);
    _controller.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final imageUrl = await _storageService.uploadChatImage(
          widget.bookingId,
          pickedFile,
        );
        if (imageUrl != null) {
          _sendMessage(imageUrl: imageUrl);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image'), backgroundColor: Colors.red),
            );
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.receiverName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Online',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chatService.getMessages(widget.bookingId, _currentUserId, widget.receiverId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading messages: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)),
                    );
                  }

                  final messages = snapshot.data ?? [];
                  
                  // Mark messages as read when they arrive
                  if (messages.isNotEmpty) {
                    _chatService.markMessagesAsRead(widget.bookingId, _currentUserId, widget.receiverId);
                  }

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : AppTheme.textSlateMedium,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == _currentUserId;

                      return _buildMessageBubble(message, isMe, isDark);
                    },
                  );
                },
              ),
            ),
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool isDark) {
    final bool hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;
    final bool hasText = message.text.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryBlue : (isDark ? AppTheme.surfaceDark : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textSlateDark.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(hasText ? 0 : (isMe ? 16 : 4)),
                    bottomRight: Radius.circular(hasText ? 0 : (isMe ? 4 : 16)),
                  ),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: isDark ? Colors.white10 : Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: double.infinity,
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Center(child: Icon(Icons.broken_image, size: 50, color: AppTheme.textSlateMedium)),
                    ),
                  ),
                ),
              if (!isMe && message.senderRole != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(12, hasImage ? 4 : 8, 12, 0),
                  child: Text(
                    message.senderRole!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.primaryBlue : AppTheme.primaryBlue,
                    ),
                  ),
                ),
              if (hasText || !hasImage)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : (isDark ? Colors.white : AppTheme.textSlateDark),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, hasText ? 0 : 8, 12, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : AppTheme.textSlateMedium,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.check,
                        size: 16,
                        color: message.isRead ? Colors.lightBlueAccent : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : const Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textSlateDark.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isUploading ? null : _sendMessage,
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: _isUploading ? AppTheme.textSlateMedium : AppTheme.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isUploading ? Colors.transparent : const Color(0x403B82F6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
