import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final nickname = appState.nickname.isNotEmpty ? appState.nickname : 'User';
          final avatar = appState.selectedAvatar.isNotEmpty 
              ? NetworkImage(appState.selectedAvatar) 
              : const NetworkImage('https://i.pravatar.cc/150?img=5'); // Fallback dummy
              
          return SingleChildScrollView(
            child: Column(
              children: [
                // Header with Blue Background and overlapping Grid
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Top Blue Background
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar with Edit Button
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [AppColors.gradientLightBlueStart, AppColors.gradientBlueEnd],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundImage: avatar as ImageProvider,
                                  ),
                                ),
                              ),
                              // Edit FAB
                              Positioned(
                                bottom: 0,
                                right: -5,
                                child: InkWell(
                                  onTap: () {
                                    // TODO: Implement Edit Profile
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Username
                          Text(
                            nickname,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40), // Space for overlapping grid
                        ],
                      ),
                    ),

                    // Overlapping Dashboard Grid
                    Positioned(
                      top: 240, // Adjust this value to overlap correctly
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(24),
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
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: '₹${appState.walletBalance.toStringAsFixed(0)}', // Live Balance
                                    subtitle: 'Earnings',
                                    icon: Icons.account_balance_wallet,
                                    iconColor: AppColors.primaryBlue,
                                    iconBgColor: AppColors.primaryBlue.withOpacity(0.1),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Refer & Earn',
                                    icon: Icons.people,
                                    iconColor: Colors.deepPurpleAccent,
                                    iconBgColor: Colors.deepPurpleAccent.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Transactions',
                                    icon: Icons.shopping_cart,
                                    iconColor: Colors.teal,
                                    iconBgColor: Colors.teal.withOpacity(0.1),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDashboardCard(
                                    title: 'Privacy',
                                    icon: Icons.security,
                                    iconColor: AppColors.gradientLightBlueStart,
                                    iconBgColor: AppColors.gradientLightBlueStart.withOpacity(0.1),
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

                // Spacing to push content below the overlapping grid
                const SizedBox(height: 200), // Adjust this value based on grid height

                // Settings & Support Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Settings & Support',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsTile(
                        title: 'Terms & Condition',
                        icon: Icons.description,
                        iconColor: Colors.orange,
                        iconBgColor: Colors.orange.withOpacity(0.1),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        title: 'Refund & Cancellation',
                        icon: Icons.attach_money,
                        iconColor: AppColors.successGreen,
                        iconBgColor: AppColors.successGreen.withOpacity(0.1),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}
