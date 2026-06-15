import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/female_expert.dart';
import 'phone_auth_screen.dart';
import 'active_call_page.dart';
import 'wallet_recharge_screen.dart';
import '../services/call_service.dart';
import '../services/matching_service.dart';
import '../services/notification_service.dart';

class MaleCallerDashboard extends StatefulWidget {
  const MaleCallerDashboard({super.key});

  @override
  State<MaleCallerDashboard> createState() => _MaleCallerDashboardState();
}

class _MaleCallerDashboardState extends State<MaleCallerDashboard> {
  final CallService _callService = CallService();
  late final MatchingService _matchingService;

  // Navigation & filter states
  int _currentTab = 0; // 0 for Home, 1 for Recents
  bool _isOnlineSwitch = true;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Star',
    'Relationship',
    'Marriage',
    'Confidence',
  ];

  // Modern Color Palette Constants
  static const Color brandBg = Color(0xFFF8FAFC); // Slate 50
  static const Color brandPrimary = Color(0xFF4F46E5); // Indigo 600
  static const Color brandAccent = Color(0xFFF43F5E); // Rose 500
  static const Color brandTextDark = Color(0xFF0F172A); // Slate 900
  static const Color brandTextGrey = Color(0xFF64748B); // Slate 500
  static const Color brandCardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService(_callService);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialWalletBalance();
    });
  }

  Future<void> _fetchInitialWalletBalance() async {
    final appState = context.read<AppState>();
    final mobile = appState.mobileNumber.isNotEmpty ? appState.mobileNumber : "test_mobile";
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(mobile).get();
      if (docSnap.exists) {
        final balance = (docSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final hasUsedFreeCall = docSnap.data()?['hasUsedFreeCall'] as bool? ?? false;
        appState.setWalletBalance(balance);
        appState.setHasUsedFreeCall(hasUsedFreeCall);
      } else {
        await FirebaseFirestore.instance.collection('users').doc(mobile).set({
          'mobileNumber': mobile,
          'walletBalance': 0.0,
          'hasUsedFreeCall': false,
          'gender': 'male',
        }, SetOptions(merge: true));
        appState.setWalletBalance(0.0);
        appState.setHasUsedFreeCall(false);
      }
      
      // Save FCM Token for push notifications
      await NotificationService.instance.saveTokenForUser(
        userId: mobile,
        collection: 'users',
      );
    } catch (e) {
      debugPrint("Error fetching wallet balance: $e");
    }
  }

  void _logout() {
    context.read<AppState>().reset();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
      (route) => false,
    );
  }

  void _addMoneyDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalletRechargeScreen()),
    );
  }

  void _triggerCall(FemaleExpert expert) async {
    final appState = context.read<AppState>();
    final balance = appState.walletBalance;
    final hasUsedFreeCall = appState.hasUsedFreeCall;
    if (balance < expert.pricePerMin && hasUsedFreeCall) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Insufficient Balance',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Your wallet balance is ₹${balance.toStringAsFixed(2)}. You need at least ₹${expert.pricePerMin} to place a call.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: brandTextGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addMoneyDialog();
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandPrimary),
              child: const Text('Recharge'),
            ),
          ],
        ),
      );
      return;
    }

    // Show a loading dialog while checking status
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: brandPrimary),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Checking availability...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final expertId = expert.nickname.toLowerCase();
      final docSnap = await FirebaseFirestore.instance
          .collection('experts_queue')
          .doc(expertId)
          .get();

      // Close the loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      bool isBusy = true;
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data['status'] == 'waiting') {
          isBusy = false;
        }
      }

      if (!isBusy) {
        // Female is online and NOT busy, call her directly!
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveCallPage(
                receiverId: expertId,
                callerId: context.read<AppState>().nickname.isNotEmpty
                    ? context.read<AppState>().nickname.toLowerCase()
                    : 'caller_1',
                nickname: expert.nickname,
                avatarPath: expert.avatarPath,
                pricePerMin: expert.pricePerMin.toDouble(),
                isCaller: true,
                isFirstFreeCall: !hasUsedFreeCall,
              ),
            ),
          );
        }
      } else {
        // Female is busy or offline, show alert and trigger matchmaking algorithm!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${expert.nickname} is busy. Connecting you to another available expert...'),
              duration: const Duration(seconds: 3),
            ),
          );
          _startRandomMatchmaking();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: $e')),
        );
      }
    }
  }

  void _startRandomMatchmaking() {
    final appState = context.read<AppState>();
    final balance = appState.walletBalance;
    final hasUsedFreeCall = appState.hasUsedFreeCall;
    const pricePerMin = 5.0;
    if (balance < pricePerMin && hasUsedFreeCall) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Insufficient Balance',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Your wallet balance is ₹${balance.toStringAsFixed(2)}. You need at least ₹$pricePerMin to place a call.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: brandTextGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addMoneyDialog();
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandPrimary),
              child: const Text('Recharge'),
            ),
          ],
        ),
      );
      return;
    }

    final String callerId = context.read<AppState>().nickname.isNotEmpty
        ? context.read<AppState>().nickname.toLowerCase()
        : 'caller_1';

    MatchController? matchController;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        matchController = _matchingService.findRandomExpertAndCall(
          callerId: callerId,
          onMatchFound: (expertId, callRoomId) {
            Navigator.pop(dialogCtx);

            FirebaseFirestore.instance
                .collection('experts')
                .doc(expertId)
                .get()
                .then((doc) {
                  String nickname = expertId.toUpperCase();
                  String avatarPath = 'assets/avatars/female_1.png';
                  if (doc.exists) {
                    final data = doc.data();
                    if (data != null) {
                      nickname = data['nickname'] ?? nickname;
                      avatarPath = data['avatarPath'] ?? avatarPath;
                    }
                  }

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActiveCallPage(
                          callRoomId: callRoomId,
                          receiverId: expertId,
                          callerId: callerId,
                          nickname: nickname,
                          avatarPath: avatarPath,
                          pricePerMin: pricePerMin,
                          isCaller: true,
                          preStartedCallService: _callService,
                          isFirstFreeCall: !hasUsedFreeCall,
                        ),
                      ),
                    );
                  }
                });
          },
          onRemoteStream: (stream) {},
          onCallEnded: () {},
          onError: (err) {
            Navigator.pop(dialogCtx);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Matchmaking error: $err')));
          },
        );

        return AlertDialog(
          title: const Text(
            'Finding Match...',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: brandPrimary),
              SizedBox(height: 20),
              Text(
                'Waiting for an expert to connect...',
                textAlign: TextAlign.center,
                style: TextStyle(color: brandTextGrey),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                matchController?.cancel();
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Matchmaking cancelled')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: brandAccent),
              child: const Text('Cancel Search'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBg,
      body: SafeArea(
        child: _currentTab == 0 ? _buildHomeTab() : _buildRecentsTab(),
      ),
      bottomNavigationBar: Container(
        height: 64,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Home Tab Button
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: _currentTab == 0
                    ? BoxDecoration(
                        color: brandPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                child: Row(
                  children: [
                    Icon(
                      _currentTab == 0
                          ? Icons.home_rounded
                          : Icons.home_outlined,
                      color: _currentTab == 0 ? brandPrimary : brandTextGrey,
                      size: 22,
                    ),
                    if (_currentTab == 0) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Home',
                        style: TextStyle(
                          color: brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Recents Tab Button
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentTab = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: _currentTab == 1
                    ? BoxDecoration(
                        color: brandPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                child: Row(
                  children: [
                    Icon(
                      _currentTab == 1
                          ? Icons.access_time_filled_rounded
                          : Icons.access_time_rounded,
                      color: _currentTab == 1 ? brandPrimary : brandTextGrey,
                      size: 22,
                    ),
                    if (_currentTab == 1) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Recents',
                        style: TextStyle(
                          color: brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Home Tab view (Redesigned 60-70% similar)
  Widget _buildHomeTab() {
    final appState = context.watch<AppState>();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('experts').snapshots(),
      builder: (context, snapshot) {
        List<FemaleExpert> liveExperts = [];
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              
              // Fallback to doc.id if nickname field is missing or empty
              String nickname = data['nickname']?.toString() ?? '';
              if (nickname.trim().isEmpty) {
                nickname = doc.id;
              }

              liveExperts.add(
                FemaleExpert(
                  nickname: nickname,
                  age: (data['age'] as num?)?.toInt() ?? 20,
                  city: data['city']?.toString() ?? 'Online',
                  pricePerMin: (data['pricePerMin'] as num?)?.toInt() ?? 5,
                  bio: data['bio']?.toString() ?? '',
                  avatarPath: data['avatarPath']?.toString() ?? 'assets/avatars/female_1.png',
                  languages: data['languages']?.toString() ?? 'Hindi',
                  rating: (() {
                    final totalSecs = (data['totalTalkSeconds'] as num?)?.toDouble() ?? 0;
                    // 0s → 3.5, 36000s (10hrs) → 5.0, always clamped to [3.5, 5.0]
                    final computed = 3.5 + (totalSecs / 36000.0) * 1.5;
                    final stored = (data['rating'] as num?)?.toDouble();
                    return double.parse((stored ?? computed.clamp(3.5, 5.0)).toStringAsFixed(1));
                  })(),
                  isOnline: data['isOnline'] == true,
                  categories: data['categories'] is List 
                      ? List<String>.from(data['categories']) 
                      : ['All'],
                ),
              );
            } catch (e) {
              debugPrint('Error parsing expert doc ${doc.id}: $e');
            }
          }
        }

        final expertsList = liveExperts.where((expert) {
          if (expert.nickname.trim().isEmpty) return false;
          if (_selectedCategory == 'All') return true;
          return expert.categories.contains(_selectedCategory);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Redesigned Top Custom Header Row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'SajniRe',
                    style: GoogleFonts.yellowtail(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: brandTextDark,
                    ),
                  ),
                  const Spacer(),
                  // Wallet Pill (Redesigned with Slate 800 + Amber tag)
                  GestureDetector(
                    onTap: _addMoneyDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '% Sale',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${appState.walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Profile Avatar with colored ring
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: brandPrimary, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: AssetImage(
                        appState.selectedAvatar.isNotEmpty
                            ? appState.selectedAvatar
                            : 'assets/male_avatar.png',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Wallet Recharge Banner
            GestureDetector(
              onTap: _addMoneyDialog,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B), // Deep Indigo dark
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Coin/wallet icon block
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('💰', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    // Text
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recharge your wallet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Talk more, pay less — top up now!',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add money chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Add ₹',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FIRST 2 MIN FREE Banner
            if (!appState.hasUsedFreeCall)
              GestureDetector(
                onTap: _startRandomMatchmaking,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Gift icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🎁', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      // Main text
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FIRST 2 MIN FREE!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tap to connect now ✨',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arrow
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                'Featured Experts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: brandTextDark,
                ),
              ),
            ),
            const SizedBox(height: 8),




            // Redesigned Experts List view
            Expanded(
              child: expertsList.isEmpty
                  ? const Center(
                      child: Text('No experts available in this category'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: expertsList.length,
                      itemBuilder: (context, index) {
                        final expert = expertsList[index];
                        return _buildExpertItemRedesigned(expert);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _triggerCallByNickname(String nickname) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('experts').doc(nickname.toLowerCase()).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final expert = FemaleExpert(
          nickname: data['nickname'] ?? nickname,
          age: data['age'] ?? 20,
          city: data['city'] ?? '',
          pricePerMin: (data['pricePerMin'] ?? 5).toDouble(),
          bio: data['bio'] ?? '',
          avatarPath: data['avatarPath'] ?? 'assets/avatars/female_1.png',
          languages: data['languages'] ?? 'Hindi',
          rating: (data['rating'] ?? 4.5).toDouble(),
          isOnline: data['isOnline'] ?? false,
          categories: List<String>.from(data['categories'] ?? ['All']),
        );
        _triggerCall(expert);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expert not found')));
        }
      }
    } catch (e) {
      debugPrint('Error fetching expert: $e');
    }
  }

  // Redesigned Recents Tab view (60-70% similar)
  Widget _buildRecentsTab() {
    final appState = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Text(
                'Recents',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: brandTextDark,
                ),
              ),
              const Spacer(),
              // Online Label and Switch
              Text(
                'Online',
                style: TextStyle(
                  color: _isOnlineSwitch ? brandPrimary : brandTextGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _isOnlineSwitch,
                onChanged: (val) {
                  setState(() {
                    _isOnlineSwitch = val;
                  });
                },
                activeColor: Colors.white,
                activeTrackColor: brandPrimary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade300,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: brandTextDark),
                onSelected: (value) {
                  if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Text('Logout'),
                    ),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('call_logs')
                  .where('callerId', isEqualTo: appState.nickname.isNotEmpty ? appState.nickname.toLowerCase() : 'caller_1')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.hasData ? snapshot.data!.docs : [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No recent calls', style: TextStyle(color: brandTextGrey)),
                  );
                }

                // Sort in memory by endedAt descending
                final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                sortedDocs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['endedAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['endedAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedDocs[index].data() as Map<String, dynamic>;
                    final expertId = data['expertId'] ?? 'Unknown';
                    final durationSeconds = data['durationSeconds'] ?? 0;
                    final endedAt = data['endedAt'] as Timestamp?;
                    
                    final m = durationSeconds ~/ 60;
                    final s = durationSeconds % 60;
                    final durationStr = '${m}m ${s}s';
                    
                    String formattedTime = '';
                    if (endedAt != null) {
                      final dt = endedAt.toDate();
                      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                      final amPm = dt.hour >= 12 ? 'pm' : 'am';
                      final minute = dt.minute.toString().padLeft(2, '0');
                      final day = dt.day.toString().padLeft(2, '0');
                      final month = dt.month.toString().padLeft(2, '0');
                      final year = dt.year.toString().substring(2);
                      formattedTime = '$day/$month/$year • $hour:$minute $amPm';
                    } else {
                      formattedTime = 'Just now';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandCardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey.shade100,
                              backgroundImage: const AssetImage('assets/avatars/female_1.png'),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        expertId,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: brandTextDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$durationStr • $formattedTime',
                                  style: const TextStyle(color: brandTextGrey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // Call Button
                          GestureDetector(
                            onTap: () => _triggerCallByNickname(expertId),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: brandPrimary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: brandPrimary.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.phone_in_talk_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Redesigned Expert List Card (60-70% similar, organic rounded shape, soft styling)
  Widget _buildExpertItemRedesigned(FemaleExpert expert) {
    // Pick a soft accent color per expert based on name hash
    final accentColors = [
      const Color(0xFFEC4899), // pink
      const Color(0xFF8B5CF6), // purple
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFF59E0B), // amber
      const Color(0xFF10B981), // emerald
      const Color(0xFFF43F5E), // rose
    ];
    final accentColor = accentColors[expert.nickname.hashCode.abs() % accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: accentColor.withOpacity(0.1),
                      backgroundImage: AssetImage(expert.avatarPath),
                    ),
                    if (expert.isOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expert.nickname,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: brandTextDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Rating pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFCD34D), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(
                                  expert.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Age, city, language in one line
                      Text(
                        '${expert.age}y · ${expert.city} · ${expert.languages}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: brandTextGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Bio
                      Text(
                        expert.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: brandTextGrey.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Right: Price + Call button
                Column(
                  children: [
                    Text(
                      '₹${expert.pricePerMin}/min',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _triggerCall(expert),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Call',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

