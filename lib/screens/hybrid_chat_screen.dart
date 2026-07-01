import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_chat_database.dart';
import '../services/hybrid_chat_service.dart';
import '../theme/app_colors.dart';

class HybridChatScreen extends StatefulWidget {
  final String myUid;
  final String otherUid;
  final String otherUserName;

  const HybridChatScreen({
    super.key,
    required this.myUid,
    required this.otherUid,
    required this.otherUserName,
  });

  @override
  State<HybridChatScreen> createState() => _HybridChatScreenState();
}

class _HybridChatScreenState extends State<HybridChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final HybridChatService _chatService = HybridChatService();
  
  late String _roomId;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _dbUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _roomId = LocalChatDatabase.generateRoomId(widget.myUid, widget.otherUid);
    
    // Set active room to prevent false delivery ACKs when we are actually reading
    HybridChatService.activeChatRoomId = _roomId;

    // Listen to local DB updates (so ticks update instantly)
    _dbUpdateSubscription = LocalChatDatabase.instance.updates.listen((_) {
      if (mounted) _loadMessages();
    });

    _initChat();
  }

  Future<void> _initChat() async {
    await _loadMessages();

    // Fetch unread messages from the OTHER user and mark them as read
    final unreadMsgs = await LocalChatDatabase.instance.getUnreadMessages(_roomId, widget.otherUid);
    for (var msg in unreadMsgs) {
      await _chatService.markAsRead(msg['msgId'] as String, widget.otherUid, widget.myUid);
    }
    
    if (unreadMsgs.isNotEmpty) {
      await _loadMessages(); // Refresh UI after marking read
    }
  }

  Future<void> _loadMessages() async {
    final messages = await LocalChatDatabase.instance.fetchChatHistory(_roomId);
    if (mounted) {
      setState(() {
        _messages = messages;
      });
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    HybridChatService.activeChatRoomId = null;
    _dbUpdateSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    
    await _chatService.sendMessage(
      roomId: _roomId,
      senderUid: widget.myUid,
      receiverUid: widget.otherUid,
      text: text,
    );
  }

  Widget _buildTickIcon(int status) {
    if (status == 1) {
      return const Icon(Icons.check, size: 16, color: Colors.grey);
    } else if (status == 2) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else if (status >= 3) {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    }
    return const SizedBox(width: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // WhatsApp-like background
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Builder(
              builder: (context) {
                final colors = [
                  const Color(0xFFE91E63), // Pink
                  const Color(0xFF9C27B0), // Purple
                  const Color(0xFF3F51B5), // Indigo
                  const Color(0xFF009688), // Teal
                  const Color(0xFFFF9800), // Orange
                  const Color(0xFF795548), // Brown
                  const Color(0xFF607D8B), // Blue Grey
                ];
                final color = colors[widget.otherUserName.hashCode.abs() % colors.length];
                
                String initials = widget.otherUserName.length >= 2 
                    ? widget.otherUserName.substring(0, 2).toUpperCase() 
                    : widget.otherUserName.toUpperCase();
                if (widget.otherUserName.startsWith('User ') && widget.otherUserName.length > 5) {
                  initials = 'U' + widget.otherUserName.substring(widget.otherUserName.length - 1);
                }

                return CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['senderId'] == widget.myUid;
                final text = msg['text'] as String;
                final timestamp = msg['timestamp'] as int;
                final status = msg['status'] as int;
                
                final timeStr = TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp)).format(context);

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFE1FFC7) : Colors.white,
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                        bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ]
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          text,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildTickIcon(status),
                            ]
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryBlue,
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
