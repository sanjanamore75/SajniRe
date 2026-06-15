import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/app_state.dart';

class RecentSessionsScreen extends StatefulWidget {
  const RecentSessionsScreen({super.key});

  @override
  State<RecentSessionsScreen> createState() => _RecentSessionsScreenState();
}

class _RecentSessionsScreenState extends State<RecentSessionsScreen> {
  String _filter = 'All'; // 'All' or 'Missed'

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUserMobile = appState.mobileNumber;
    final currentNickname = appState.nickname.toLowerCase();
    
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
                  _buildFilterChip(
                    'All', 
                    isActive: _filter == 'All',
                    onTap: () => setState(() => _filter = 'All'),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterChip(
                    'Missed', 
                    isActive: _filter == 'Missed',
                    icon: Icons.phone_missed, 
                    iconColor: _filter == 'Missed' ? Colors.white : Colors.red,
                    onTap: () => setState(() => _filter = 'Missed'),
                  ),
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

            // List View connected to Firestore 'call_logs' collection
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('call_logs')
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

                  // Filter calls relevant to current user and the selected filter
                  final userCalls = snapshot.data!.docs.where((doc) {
                     final data = doc.data() as Map<String, dynamic>;
                     final matchesUser = data['callerId'] == currentUserMobile || 
                                         data['receiverId'] == currentUserMobile ||
                                         data['receiverId'] == currentNickname ||
                                         data['callerId'] == currentNickname;
                     if (!matchesUser) return false;

                     if (_filter == 'Missed') {
                       return data['status'] == 'missed';
                     }
                     return true; // 'All'
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
                      final isMissed = data['status'] == 'missed';
                      
                      String timeText = 'Unknown Time';
                      if (data['createdAt'] != null) {
                         final DateTime dt = (data['createdAt'] as Timestamp).toDate();
                         timeText = '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      }

                      // Determine duration text
                      String durationText = isMissed ? 'Missed Call' : 'Ended';
                      if (!isMissed && data['durationSeconds'] != null) {
                        final sec = data['durationSeconds'] as int;
                        final m = sec ~/ 60;
                        final s = sec % 60;
                        durationText = '${m}m ${s}s';
                      }

                      final collectionName = isCaller ? 'experts' : 'users';
                      
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection(collectionName).doc(otherUserId).get(),
                        builder: (context, profileSnapshot) {
                          String avatarPath = isCaller ? 'assets/avatars/female_1.png' : 'assets/avatars/male_1.png';
                          String displayName = otherUserId ?? 'Unknown';

                          if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                            final profileData = profileSnapshot.data!.data() as Map<String, dynamic>;
                            if (profileData['avatarPath'] != null && profileData['avatarPath'].toString().isNotEmpty) {
                              avatarPath = profileData['avatarPath'];
                            }
                            if (profileData['nickname'] != null && profileData['nickname'].toString().isNotEmpty) {
                              displayName = profileData['nickname'];
                            }
                          }

                          // Also check if it's one of the dummy experts to give it the right avatar
                          if (isCaller) {
                            final List<Map<String, String>> dummyAvatars = [
                              {'name': 'sneha', 'path': 'assets/avatars/female_1.png'},
                              {'name': 'priya', 'path': 'assets/avatars/female_2.png'},
                              {'name': 'riya', 'path': 'assets/avatars/female_3.png'},
                              {'name': 'kavya', 'path': 'assets/avatars/female_4.png'},
                              {'name': 'ananya', 'path': 'assets/avatars/female_5.png'},
                              {'name': 'meera', 'path': 'assets/avatars/female_6.png'},
                            ];
                            for (var dummy in dummyAvatars) {
                              if (displayName.toLowerCase() == dummy['name']) {
                                avatarPath = dummy['path']!;
                                displayName = dummy['name']![0].toUpperCase() + dummy['name']!.substring(1);
                              }
                            }
                          }

                          return _buildCallCard(
                            name: displayName,
                            timeText: timeText,
                            duration: durationText,
                            cost: isMissed ? '₹0' : 'Ended',
                            avatarUrl: avatarPath,
                            isMissed: isMissed,
                          );
                        },
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

  Widget _buildFilterChip(String label, {bool isActive = false, IconData? icon, Color? iconColor, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  Widget _buildCallCard({
    required String name,
    required String timeText,
    required String duration,
    required String cost,
    required String avatarUrl,
    required bool isMissed,
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isMissed 
                  ? [Colors.red.shade300, Colors.red.shade700] 
                  : [AppColors.gradientBlueStart, AppColors.gradientBlueEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 28,
                backgroundImage: avatarUrl.startsWith('http')
                    ? NetworkImage(avatarUrl) as ImageProvider
                    : AssetImage(avatarUrl),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMissed ? Colors.red.shade700 : AppColors.textDark,
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
                    Icon(
                      isMissed ? Icons.phone_missed : Icons.access_time, 
                      size: 14, 
                      color: isMissed ? Colors.red : AppColors.primaryBlue
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMissed ? Colors.red : AppColors.primaryBlue,
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
                  color: isMissed 
                    ? Colors.red.withOpacity(0.1) 
                    : AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cost,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isMissed ? Colors.red : AppColors.successGreen,
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
