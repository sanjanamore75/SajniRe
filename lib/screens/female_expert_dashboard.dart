import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'phone_auth_screen.dart';
import 'active_call_page.dart';
import '../services/call_service.dart';
import '../services/matching_service.dart';


class FemaleExpertDashboard extends StatefulWidget {
  const FemaleExpertDashboard({super.key});

  @override
  State<FemaleExpertDashboard> createState() => _FemaleExpertDashboardState();
}

class _FemaleExpertDashboardState extends State<FemaleExpertDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final CallService _callService = CallService();
  late final MatchingService _matchingService;
  StreamSubscription? _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService(_callService);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start listening for calls if already online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.isOnline) {
        _startIncomingCallListener(appState.nickname.toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _stopIncomingCallListener();
    _pulseController.dispose();
    super.dispose();
  }

  void _startIncomingCallListener(String expertId) {
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = _callService.listenForIncomingCalls(
      expertId: expertId,
      onCallReceived: (roomId, callerId) {
        _showIncomingCallDialog(roomId, callerId);
      },
    );
  }

  void _stopIncomingCallListener() {
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;
  }

  Future<void> _updateOnlineStatus(bool value) async {
    final appState = context.read<AppState>();
    appState.setOnlineStatus(value);
    
    final String expertId = appState.nickname.toLowerCase();
    if (expertId.isNotEmpty) {
      try {
        await _matchingService.setExpertOnlineStatus(expertId, value);
        await FirebaseFirestore.instance.collection('experts').doc(expertId).set({
          'nickname': appState.nickname,
          'age': 2026 - appState.birthYear,
          'city': 'Online',
          'pricePerMin': 5,
          'bio': 'Talk to me about life, love, and everything in between.',
          'avatarPath': appState.selectedAvatar.isNotEmpty
              ? appState.selectedAvatar
              : 'assets/avatars/female_1.png',
          'languages': appState.primaryLanguage,
          'rating': 4.8,
          'isOnline': value,
          'categories': ['All', 'Relationship', 'Star'],
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating online status: $e');
      }
    }

    if (value) {
      _startIncomingCallListener(expertId);
    } else {
      _stopIncomingCallListener();
    }
  }

  void _showIncomingCallDialog(String roomId, String callerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('User "$callerId" is calling you.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _callService.endCall(roomId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveCallPage(
                    callRoomId: roomId,
                    receiverId: context.read<AppState>().nickname.toLowerCase(),
                    callerId: callerId,
                    nickname: callerId,
                    avatarPath: '',
                    pricePerMin: 5.0,
                    isCaller: false,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }


  void _logout() {
    final appState = context.read<AppState>();
    final String expertId = appState.nickname.toLowerCase();
    if (expertId.isNotEmpty) {
      _matchingService.setExpertOnlineStatus(expertId, false).catchError((e) {
        debugPrint('Error removing expert from queue: $e');
      });
      FirebaseFirestore.instance.collection('experts').doc(expertId).update({
        'isOnline': false,
      }).catchError((e) => debugPrint('Error resetting online status: $e'));
    }
    _stopIncomingCallListener();
    appState.reset();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isOnline = appState.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout / Reset',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Avatar with Online indicator pulse
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isOnline)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 170 + (_pulseController.value * 30),
                            height: 170 + (_pulseController.value * 30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.2 * (1 - _pulseController.value)),
                            ),
                          );
                        },
                      ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOnline ? Colors.green : AppTheme.borderGrey,
                          width: 4.0,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: AppTheme.inputBg,
                        backgroundImage: appState.selectedAvatar.isNotEmpty
                            ? AssetImage(appState.selectedAvatar)
                            : const AssetImage('assets/avatars/female_1.png'),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.green : Colors.grey,
                          border: Border.all(color: Colors.white, width: 2.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nickname
              Text(
                appState.nickname.isNotEmpty ? appState.nickname : 'Expert Name',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textBlack,
                ),
              ),
              const SizedBox(height: 4),

              // Primary Language Tag
              Text(
                'Primary Language: ${appState.primaryLanguage}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              // Total Earnings Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.inputBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderGrey, width: 1.0),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL EARNINGS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textGrey,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${appState.totalEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Switch Online / Offline controls
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green.withOpacity(0.08) : AppTheme.inputBg,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isOnline ? Colors.green.withOpacity(0.3) : AppTheme.borderGrey,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.green : AppTheme.textGrey,
                          ),
                        ),
                        Switch(
                          value: isOnline,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey.withOpacity(0.2),
                          onChanged: (bool value) {
                            _updateOnlineStatus(value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Turn ON to receive incoming calls from users',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
