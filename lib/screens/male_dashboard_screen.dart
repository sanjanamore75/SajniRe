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
        appState.setWalletBalance(balance);
      } else {
        await FirebaseFirestore.instance.collection('users').doc(mobile).set({
          'mobileNumber': mobile,
          'walletBalance': 20.0,
          'gender': 'male', // Explicitly mark as male
        }, SetOptions(merge: true));
        appState.setWalletBalance(20.0);
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
    final balance = context.read<AppState>().walletBalance;
    if (balance < expert.pricePerMin) {
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
    final balance = context.read<AppState>().walletBalance;
    const pricePerMin = 5.0;
    if (balance < pricePerMin) {
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
              liveExperts.add(
                FemaleExpert(
                  nickname: data['nickname'] ?? '',
                  age: data['age'] ?? 20,
                  city: data['city'] ?? 'Online',
                  pricePerMin: data['pricePerMin'] ?? 5,
                  bio: data['bio'] ?? '',
                  avatarPath:
                      data['avatarPath'] ?? 'assets/avatars/female_1.png',
                  languages: data['languages'] ?? 'Hindi',
                  rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
                  isOnline: data['isOnline'] ?? false,
                  categories: List<String>.from(data['categories'] ?? ['All']),
                ),
              );
            } catch (e) {
              debugPrint('Error parsing expert doc: $e');
            }
          }
        }

        final allExperts = [...liveExperts];
        for (var mock in FemaleExpert.mockExperts) {
          if (!allExperts.any(
            (e) => e.nickname.toLowerCase() == mock.nickname.toLowerCase(),
          )) {
            allExperts.add(mock);
          }
        }

        final expertsList = allExperts.where((expert) {
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

            // Redesigned Cashback Banner Card (Teal to Indigo gradient, ambient shadow)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), brandPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: brandPrimary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Avail cashbacks',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'upto 60%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'on recharges!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addMoneyDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: brandPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Buy Now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Redesigned Call Option Container (Soft violet, Indigo button)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF), // Indigo 50
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: brandPrimary.withValues(alpha: 0.1),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brandPrimary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shuffle_rounded,
                      color: brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect & Make Friends',
                          style: TextStyle(
                            color: brandTextDark,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '@ ₹5/min only!',
                          style: TextStyle(
                            color: brandPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _startRandomMatchmaking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Random Call',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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

            // Redesigned Category Chips List (Outlined or soft pill style)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? brandPrimary
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : brandTextGrey,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

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

  // Redesigned Recents Tab view (60-70% similar)
  Widget _buildRecentsTab() {
    const soniKumariExpert = FemaleExpert(
      nickname: "Soni kumari",
      age: 23,
      city: "Delhi, DL",
      pricePerMin: 5,
      bio: "Talk to me about life, love, and everything in between.",
      avatarPath: "assets/avatars/female_1.png",
      languages: "Hindi",
      rating: 4.8,
      isOnline: true,
      categories: ["All"],
    );

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
          const SizedBox(height: 4),
          const Text(
            'Jun 07, 2026',
            style: TextStyle(
              color: brandTextGrey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Redesigned Recents List Item Card
          Container(
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
                // Avatar with orange dot and "Busy" label
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: const AssetImage(
                          'assets/avatars/female_1.png',
                        ),
                      ),
                    ),
                    // Small Orange Dot (top-right)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.0),
                        ),
                      ),
                    ),
                    // "Busy" Badge (overlapping bottom)
                    Positioned(
                      bottom: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Busy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Center Username and Duration/Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Soni kumari',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: brandTextDark,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text('💗', style: TextStyle(fontSize: 14)),
                          const Text(
                            ',',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '0m 33s • 1:01 pm',
                        style: TextStyle(color: brandTextGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Right side circular Blue Call Button (Sleek circle with brand primary)
                GestureDetector(
                  onTap: () => _triggerCall(soniKumariExpert),
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
          ),
        ],
      ),
    );
  }

  // Redesigned Expert List Card (60-70% similar, organic rounded shape, soft styling)
  Widget _buildExpertItemRedesigned(FemaleExpert expert) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Avatar, Online Badge, Rating
              Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: expert.isOnline
                                ? Colors.green.shade200
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: AssetImage(expert.avatarPath),
                        ),
                      ),
                      if (expert.isOnline)
                        Positioned(
                          bottom: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Online',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Rating Badge (Gold Pill Container)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // Amber 100
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD97706),
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          expert.rating.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Center Details: Name, Age, Location, Category Tag, Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                expert.nickname,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: brandTextDark,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '• ${expert.age} Y',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: brandTextGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          expert.languages,
                          style: const TextStyle(
                            fontSize: 11,
                            color: brandTextGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expert.city,
                      style: const TextStyle(
                        fontSize: 12,
                        color: brandTextGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Category Tag styled in Coral Accent
                    Text(
                      expert.categories.length > 1
                          ? expert.categories[1]
                          : expert.categories.first,
                      style: const TextStyle(
                        color: brandAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${expert.pricePerMin}/min',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: brandTextDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Right side: Call Now Button
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _triggerCall(expert),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_in_talk_rounded, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Call Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bio Quote
          Text(
            '"${expert.bio}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: brandTextGrey,
            ),
          ),
        ],
      ),
    );
  }
}
