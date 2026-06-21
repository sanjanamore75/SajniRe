import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/female_expert.dart';
import 'phone_auth_screen.dart';
import 'active_call_page.dart';
import 'wallet_recharge_screen.dart';
import 'matchmaking_screen.dart';
import 'incoming_call_screen.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';

class MaleCallerDashboard extends StatefulWidget {
  const MaleCallerDashboard({super.key});

  @override
  State<MaleCallerDashboard> createState() => _MaleCallerDashboardState();
}

class _MaleCallerDashboardState extends State<MaleCallerDashboard> {
  final CallService _callService = CallService();

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

  // Pagination State
  final int _expertsLimit = 40;
  List<FemaleExpert> _liveExperts = [];
  DocumentSnapshot? _lastExpertDoc;
  bool _isFetchingExperts = false;
  bool _hasMoreExperts = true;
  final ScrollController _scrollController = ScrollController();
  
  StreamSubscription? _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchExperts();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure we have a valid Firebase Auth session (anonymous) so Firestore
      // rules (request.auth != null) are satisfied before any reads.
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
          debugPrint('[MALE_DASH] signInAnonymously success uid=${FirebaseAuth.instance.currentUser?.uid}');
        } catch (e) {
          debugPrint('[MALE_DASH] signInAnonymously error: $e');
        }
      } else {
        debugPrint('[MALE_DASH] already signed in uid=${FirebaseAuth.instance.currentUser?.uid}');
      }
      
      // DEBUG: Force insert an online expert
      try {
        await FirebaseFirestore.instance.collection('experts').doc('test_expert').set({
          'nickname': 'Test Expert',
          'isOnline': true,
          'categories': ['All'],
          'city': 'Test City',
          'pricePerMin': 5,
        });
        debugPrint('[MALE_DASH] Inserted test expert!');
      } catch (e) {
        debugPrint('[MALE_DASH] Failed to insert test expert: $e');
      }

      _setupMalePresenceAndCallListener();
      _fetchInitialWalletBalance();
    });
  }

  void _setupMalePresenceAndCallListener() {
    final appState = context.read<AppState>();
    final mobile = appState.mobileNumber.isNotEmpty ? appState.mobileNumber : "test_mobile";
    
    // Setup RTDB Presence
    final presenceRef = FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: 'https://zegochat-c44b0.asia-southeast1.firebasedatabase.app',
    ).ref('status/$mobile');
    
    presenceRef.set({
      'isOnline': true,
      'status': 'online',
      'lastChanged': ServerValue.timestamp,
    });
    presenceRef.onDisconnect().update({
      'isOnline': false,
      'status': 'offline',
      'lastChanged': ServerValue.timestamp,
    });

    // Listen for incoming calls
    _incomingCallSubscription = CallService().listenForIncomingCalls(
      expertId: mobile, // Male user receives the call
      onCallReceived: (roomId, callerId) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callRoomId: roomId,
              callerId: callerId,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchExperts();
    }
  }

  Future<void> _fetchExperts() async {
    if (_isFetchingExperts || !_hasMoreExperts) return;
    
    setState(() {
      _isFetchingExperts = true;
    });

    try {
      var query = FirebaseFirestore.instance.collection('experts').limit(_expertsLimit);
      
      if (_lastExpertDoc != null) {
        query = query.startAfterDocument(_lastExpertDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _expertsLimit) {
        _hasMoreExperts = false;
      }

      List<FemaleExpert> newExperts = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          String nickname = data['nickname']?.toString() ?? '';
          if (nickname.trim().isEmpty) nickname = doc.id;

          newExperts.add(
            FemaleExpert(
              nickname: nickname,
              age: (data['age'] as num?)?.toInt() ?? 20,
              city: data['city'] ?? 'Online',
              pricePerMin: (data['pricePerMin'] as num?)?.toInt() ?? 5,
              bio: data['bio'] ?? '',
              avatarPath: data['avatarPath'] ?? 'assets/avatars/female_1.png',
              languages: data['languages']?.toString() ?? 'Hindi',
              rating: (() {
                final totalSecs = (data['totalTalkSeconds'] as num?)?.toDouble() ?? 0;
                final computed = 3.5 + (totalSecs / 36000.0) * 1.5;
                final stored = (data['rating'] as num?)?.toDouble();
                return double.parse((stored ?? computed.clamp(3.5, 5.0)).toStringAsFixed(1));
              })(),
              isOnline: false,
              categories: List<String>.from((data['categories'] as List<dynamic>?) ?? ['All']),
            ),
          );
        } catch (e) {
          debugPrint('Error parsing expert doc: $e');
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastExpertDoc = snapshot.docs.last;
        _liveExperts.addAll(newExperts);
      }
    } catch (e) {
      debugPrint('Error fetching experts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingExperts = false;
        });
      }
    }
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
        
        final nickname = docSnap.data()?['nickname'] as String? ?? '';
        final avatarPath = docSnap.data()?['avatarPath'] as String? ?? '';
        if (nickname.isNotEmpty) {
          appState.setNickname(nickname);
        }
        if (avatarPath.isNotEmpty) {
          appState.setSelectedAvatar(avatarPath);
        }
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchmakingScreen(
          requestedExpert: expert,
          isRandomMode: false,
        ),
      ),
    );
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MatchmakingScreen(
          isRandomMode: true,
        ),
      ),
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

    // Generate Dummy Experts for UI Display
    List<FemaleExpert> dummyExperts = [
      FemaleExpert(nickname: 'Sneha', age: 22, city: 'Mumbai', pricePerMin: 5, bio: 'Love chatting about life', avatarPath: 'assets/avatars/female_1.png', languages: 'Hindi, English', rating: 4.8, isOnline: true, categories: ['All', 'Relationship']),
      FemaleExpert(nickname: 'Priya', age: 24, city: 'Delhi', pricePerMin: 5, bio: 'Friendly advisor here for you', avatarPath: 'assets/avatars/female_2.png', languages: 'Hindi', rating: 4.9, isOnline: true, categories: ['All', 'Marriage']),
      FemaleExpert(nickname: 'Riya', age: 21, city: 'Pune', pricePerMin: 5, bio: 'Let\'s be good friends!', avatarPath: 'assets/avatars/female_3.png', languages: 'Hindi', rating: 4.7, isOnline: true, categories: ['All', 'Star']),
      FemaleExpert(nickname: 'Kavya', age: 25, city: 'Bangalore', pricePerMin: 5, bio: 'Relationship expert and listener', avatarPath: 'assets/avatars/female_4.png', languages: 'Hindi, English', rating: 4.9, isOnline: true, categories: ['All', 'Confidence']),
      FemaleExpert(nickname: 'Ananya', age: 23, city: 'Kolkata', pricePerMin: 5, bio: 'Always here to listen to you', avatarPath: 'assets/avatars/female_5.png', languages: 'Hindi, Bengali', rating: 4.6, isOnline: true, categories: ['All', 'Relationship']),
      FemaleExpert(nickname: 'Meera', age: 26, city: 'Jaipur', pricePerMin: 5, bio: 'Life coach and confident speaker', avatarPath: 'assets/avatars/female_6.png', languages: 'Hindi', rating: 4.8, isOnline: true, categories: ['All', 'Marriage']),
    ];

    // Combine DB online experts with dummy experts
    final allAvailableExperts = [..._liveExperts, ...dummyExperts];

    final expertsList = allAvailableExperts.where((expert) {
      if (expert.nickname.trim().isEmpty) return false;
      if (_selectedCategory == 'All') return true;
      return expert.categories.contains(_selectedCategory);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            // --- RAW FIREBASE DATA DEBUG ---
            Container(
              color: Colors.red.shade900,
              padding: const EdgeInsets.all(8),
              child: Text(
                'DEBUG: Loaded Experts=${_liveExperts.length}\n' +
                (_liveExperts.take(3).map((e) => '${e.nickname}').join('\n') + (_liveExperts.length > 3 ? '\n...' : '')),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            // -------------------------------
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
              child: expertsList.isEmpty && _isFetchingExperts
                  ? const Center(child: CircularProgressIndicator())
                  : expertsList.isEmpty
                      ? const Center(child: Text('No experts available in this category'))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: expertsList.length + (_hasMoreExperts ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == expertsList.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final expert = expertsList[index];
                            return _buildExpertItemRedesigned(expert);
                          },
                        ),
            ),
          ],
        );
  }

  void _triggerCallByNickname(String nickname) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('experts').doc(nickname.toLowerCase()).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        bool isOnline = false;
        try {
          final rtdb = FirebaseDatabase.instanceFor(
            app: FirebaseDatabase.instance.app,
            databaseURL: 'https://zegochat-c44b0.asia-southeast1.firebasedatabase.app',
          );
          final event = await rtdb.ref('status/${nickname.toLowerCase()}/isOnline').once();
          if (event.snapshot.value != null) {
            isOnline = event.snapshot.value == true;
          }
        } catch (e) {
          debugPrint('Error fetching RTDB status: $e');
        }

        final expert = FemaleExpert(
          nickname: data['nickname'] ?? nickname,
          age: (data['age'] as num?)?.toInt() ?? 20,
          city: data['city'] ?? '',
          pricePerMin: (data['pricePerMin'] as num?)?.toInt() ?? 5,
          bio: data['bio'] ?? '',
          avatarPath: data['avatarPath'] ?? 'assets/avatars/female_1.png',
          languages: data['languages'] ?? 'Hindi',
          rating: (data['rating'] ?? 4.5).toDouble(),
          isOnline: isOnline,
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
                  .where('callerId', isEqualTo: appState.mobileNumber)
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
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
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
                    final endedAt = data['createdAt'] as Timestamp?;
                    
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

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('experts').doc(expertId).get(),
                      builder: (context, expertSnap) {
                        String avatarPath = 'assets/avatars/female_1.png';
                        String displayName = expertId;
                        
                        if (expertSnap.hasData && expertSnap.data!.exists) {
                          final expertData = expertSnap.data!.data() as Map<String, dynamic>?;
                          if (expertData != null) {
                            avatarPath = expertData['avatarPath'] ?? avatarPath;
                            displayName = expertData['nickname'] ?? displayName;
                          }
                        }

                        // Also check if it's one of the dummy experts to give it the right avatar
                        final List<Map<String, String>> dummyAvatars = [
                          {'name': 'sneha', 'path': 'assets/avatars/female_1.png'},
                          {'name': 'priya', 'path': 'assets/avatars/female_2.png'},
                          {'name': 'riya', 'path': 'assets/avatars/female_3.png'},
                          {'name': 'kavya', 'path': 'assets/avatars/female_4.png'},
                          {'name': 'ananya', 'path': 'assets/avatars/female_5.png'},
                          {'name': 'meera', 'path': 'assets/avatars/female_6.png'},
                        ];
                        
                        for (var dummy in dummyAvatars) {
                          if (expertId.toLowerCase() == dummy['name']) {
                            avatarPath = dummy['path']!;
                            displayName = dummy['name']![0].toUpperCase() + dummy['name']!.substring(1);
                          }
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
                                  backgroundImage: AssetImage(avatarPath),
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
                                            displayName,
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
                // Avatar with live online indicator (RTDB - Low Cost)
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: accentColor.withOpacity(0.1),
                      backgroundImage: AssetImage(expert.avatarPath),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instanceFor(
                          app: FirebaseDatabase.instance.app,
                          databaseURL: 'https://zegochat-c44b0.asia-southeast1.firebasedatabase.app',
                        ).ref('status/${expert.nickname.toLowerCase()}/isOnline').onValue,
                        builder: (context, snapshot) {
                          Color statusColor = Colors.grey;

                          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                            bool isOnline = snapshot.data!.snapshot.value == true;
                            if (isOnline) {
                              statusColor = const Color(0xFF22C55E); // Green
                            } else {
                              statusColor = Colors.grey; // Offline
                            }
                          } else if (expert.isOnline) {
                            // Fallback to Firestore static data if RTDB is empty
                            statusColor = const Color(0xFF22C55E);
                          } else {
                            // Offline
                            return const SizedBox.shrink(); 
                          }

                          return Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          );
                        },
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

