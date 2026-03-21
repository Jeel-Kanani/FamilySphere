import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:familysphere_app/core/theme/app_theme.dart';
import 'package:familysphere_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:familysphere_app/features/chat/domain/entities/chat_message_entity.dart';
import 'package:familysphere_app/features/auth/presentation/providers/auth_provider.dart';

class FamilyChatScreen extends ConsumerStatefulWidget {
  const FamilyChatScreen({super.key});

  @override
  ConsumerState<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends ConsumerState<FamilyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadMessages();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scroll to bottom when new messages arrive
    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFE7DE),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Family Chat',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'online',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.greenAccent),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF202C33) : AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.videocam_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading && chatState.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isMe = message.senderId == (user?.id ?? '');
                      
                      // Check if we should show date header
                      bool showDate = false;
                      if (index == 0) {
                        showDate = true;
                      } else {
                        final prevMessage = chatState.messages[index - 1];
                        if (prevMessage.createdAt.day != message.createdAt.day) {
                          showDate = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDate) _buildDateHeader(message.createdAt, isDark),
                          _buildChatBubble(context, message, isMe, isDark),
                        ],
                      );
                    },
                  ),
          ),
          _buildMessageInput(context, isDark),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182229) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2),
        ],
      ),
      child: Text(
        _formatDate(date),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, ChatMessageEntity message, bool isMe, bool isDark) {
    final bubbleColor = isMe 
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);
    
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2, right: 8),
                        child: Text(
                          message.senderName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getMemberColor(message.senderName),
                          ),
                        ),
                      ),
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 44, bottom: 2),
                          child: Text(
                            message.content,
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 14,
                                  color: message.status == 'read' 
                                      ? Colors.blue 
                                      : (isDark ? Colors.white54 : Colors.black45),
                                ),
                              ],
                            ],
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
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.add_rounded, color: isDark ? Colors.white70 : Colors.black54),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A3942) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00A884), // WhatsApp Send Button Color
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  ref.read(chatProvider.notifier).sendMessage(content: _messageController.text.trim());
                  _messageController.clear();
                  _scrollToBottom();
                }
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemberColor(String name) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.deepOrange,
    ];
    return colors[name.length % colors.length];
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'TODAY';
    }
    if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      return 'YESTERDAY';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
