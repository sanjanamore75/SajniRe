import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/app_state.dart';

class RecentSessionsScreen extends StatelessWidget {
  const RecentSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserMobile = context.watch<AppState>().mobileNumber;
    
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
              child: Text(
                'Recent Session',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),

            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _buildFilterChip('All', isActive: true),
                  const SizedBox(width: 10),
                  _buildFilterChip('Missed', icon: Icons.phone_missed, iconColor: Colors.red),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // List View connected to Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('calls')
                    .where('status', isEqualTo: 'ended')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading calls: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Filter calls relevant to current user
                  final userCalls = snapshot.data!.docs.where((doc) {
                     final data = doc.data() as Map<String, dynamic>;
                     return data['callerId'] == currentUserMobile || data['receiverId'] == currentUserMobile;
                  }).toList();

                  userCalls.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['createdAt'] as Timestamp?;
                    final bTime = bData['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  if (userCalls.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: userCalls.length,
                    itemBuilder: (context, index) {
                      final doc = userCalls[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final isCaller = data['callerId'] == currentUserMobile;
                      final otherUserId = isCaller ? data['receiverId'] : data['callerId'];
                      
                      String timeText = 'Unknown Time';
                      if (data['createdAt'] != null) {
                         final DateTime dt = (data['createdAt'] as Timestamp).toDate();
                         timeText = '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      }

                      return _buildCallCard(
                        name: otherUserId ?? 'Unknown',
                        timeText: timeText,
                        duration: 'Ended',
                        cost: '₹0', 
                        avatarUrl: 'https://i.pravatar.cc/150?u=$otherUserId',
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
          Icon(Icons.history_toggle_off, size: 64, color: AppColors.textGrey),
          SizedBox(height: 16),
          Text(
            'No recent sessions yet.',
            style: TextStyle(fontSize: 18, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isActive = false, IconData? icon, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryBlue : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppColors.primaryBlue : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textGrey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallCard({
    required String name,
    required String timeText,
    required String duration,
    required String cost,
    required String avatarUrl,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with gradient border
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.gradientBlueStart, AppColors.gradientBlueEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(avatarUrl),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Details
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.phone, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cost,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successGreen,
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
