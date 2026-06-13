import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/app_state.dart';
import '../services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _selectedTab = 0; // 0 for FRIENDS, 1 for GENERAL
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    final currentUserMobile = context.watch<AppState>().mobileNumber;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Tab Bar
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTab('FRIENDS', 0)),
                  Expanded(child: _buildTab('GENERAL', 1)),
                ],
              ),
            ),

            // List View connected to Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getUserChats(currentUserMobile),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading chats: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final chatDocs = snapshot.data!.docs.toList();
                  chatDocs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['lastUpdated'] as Timestamp?;
                    final bTime = bData['lastUpdated'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: chatDocs.length,
                    itemBuilder: (context, index) {
                      final doc = chatDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final participants = List<String>.from(data['participants'] ?? []);
                      final otherUser = participants.firstWhere(
                        (p) => p != currentUserMobile, 
                        orElse: () => 'Unknown',
                      );

                      final avatarUrl = 'https://i.pravatar.cc/150?u=$otherUser';
                      
                      String dayText = 'Just now';
                      if (data['lastUpdated'] != null) {
                         final dt = (data['lastUpdated'] as Timestamp).toDate();
                         dayText = '${dt.day}/${dt.month}';
                      }

                      return _buildChatCard(
                        name: otherUser,
                        lastMessage: data['lastMessage'] ?? 'New Chat',
                        dayText: dayText,
                        avatarUrl: avatarUrl,
                        isPinned: false, 
                        isMuted: false,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textGrey),
          SizedBox(height: 16),
          Text(
            'No active chats.',
            style: TextStyle(fontSize: 18, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primaryBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? AppColors.primaryBlue : AppColors.textGrey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard({
    required String name,
    required String lastMessage,
    required String dayText,
    required String avatarUrl,
    required bool isPinned,
    required bool isMuted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Avatar, Name, Message, Icons, Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (isPinned)
                        const Icon(Icons.push_pin, size: 18, color: AppColors.textGrey),
                      if (isPinned) const SizedBox(width: 8),
                      if (isMuted)
                        const Icon(Icons.notifications_off, size: 18, color: AppColors.textGrey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bottom Row: Action Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientBlueStart, AppColors.gradientBlueEnd],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Icon(Icons.phone, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientLightBlueStart, AppColors.gradientLightBlueEnd],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
