import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../services/call_service.dart';
import '../services/matching_service.dart';
import 'active_call_page.dart';
import 'phone_auth_screen.dart';
import '../services/notification_service.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen>
    with TickerProviderStateMixin {
  bool _isAudioOn = false;
  int _totalTalktimeMinutes = 0;
  double _redeemableBalance = 0.0;
  bool _isLoadingStats = true;

  final CallService _callService = CallService();
  late final MatchingService _matchingService;
  StreamSubscription? _incomingCallSubscription;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _cardSlideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService(_callService);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.08).animate(_pulseController);

    _cardSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _cardSlideController, curve: Curves.easeOutCubic));
    _cardSlideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExpertStats();
      final appState = context.read<AppState>();
      setState(() => _isAudioOn = appState.isOnline);
      if (appState.isOnline) {
        _startIncomingCallListener(appState.nickname.toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _pulseController.dispose();
    _cardSlideController.dispose();
    super.dispose();
  }

  // ── Firestore ──────────────────────────────────────────────────────────

  Future<void> _fetchExpertStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    final appState = context.read<AppState>();
    final expertId = appState.nickname.toLowerCase();
    if (expertId.isEmpty) {
      setState(() => _isLoadingStats = false);
      return;
    }
    
    // Save FCM Token for push notifications
    await NotificationService.instance.saveTokenForUser(
      userId: expertId,
      collection: 'experts',
    );
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('experts')
          .doc(expertId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _totalTalktimeMinutes =
              (data['totalTalktimeMinutes'] as num?)?.toInt() ?? 0;
          _redeemableBalance =
              (data['redeemableBalance'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching expert stats: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _updateOnlineStatus(bool value) async {
    final appState = context.read<AppState>();
    appState.setOnlineStatus(value);
    setState(() => _isAudioOn = value);

    final String expertId = appState.nickname.toLowerCase();
    if (expertId.isNotEmpty) {
      try {
        await _matchingService.setExpertOnlineStatus(expertId, value);
        await FirebaseFirestore.instance
            .collection('experts')
            .doc(expertId)
            .set({
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
      _incomingCallSubscription?.cancel();
    }
  }

  void _startIncomingCallListener(String expertId) {
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = _callService.listenForIncomingCalls(
      expertId: expertId,
      onCallReceived: (roomId, callerId) =>
          _showIncomingCallDialog(roomId, callerId),
    );
  }

  void _showIncomingCallDialog(String roomId, String callerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: AppColors.lightBlueBg, shape: BoxShape.circle),
            child: const Icon(Icons.call_received,
                color: AppColors.primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Incoming Call',
              style: TextStyle(
                  color: AppColors.textDark, fontWeight: FontWeight.bold)),
        ]),
        content: Text('User "$callerId" is calling you.',
            style: const TextStyle(color: AppColors.textGrey)),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _callService.endCall(roomId);
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red)),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveCallPage(
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    if (_redeemableBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No redeemable balance to withdraw.'),
          backgroundColor: AppColors.textGrey));
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Withdraw Earnings',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: Text(
          'Withdraw ₹${_redeemableBalance.toStringAsFixed(0)} to your registered bank account?\n\nTransfer takes 3–5 business days.',
          style: const TextStyle(color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textGrey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _processWithdrawal();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawal() async {
    final expertId = context.read<AppState>().nickname.toLowerCase();
    if (expertId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('withdrawal_requests').add({
        'expertId': expertId,
        'amount': _redeemableBalance,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('experts')
          .doc(expertId)
          .update({'redeemableBalance': 0.0});
      if (mounted) {
        setState(() => _redeemableBalance = 0.0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Withdrawal request submitted!'),
            backgroundColor: AppColors.successGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _logout() {
    final appState = context.read<AppState>();
    final expertId = appState.nickname.toLowerCase();
    if (expertId.isNotEmpty) {
      _matchingService
          .setExpertOnlineStatus(expertId, false)
          .catchError((e) => debugPrint('Error: $e'));
      FirebaseFirestore.instance
          .collection('experts')
          .doc(expertId)
          .update({'isOnline': false}).catchError((e) => null);
    }
    _incomingCallSubscription?.cancel();
    appState.reset();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
      (route) => false,
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Use nickname from AppState — the actual registered name, not "Expert"
    final String displayName = appState.nickname.isNotEmpty
        ? appState.nickname
        : 'there';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: _fetchExpertStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(displayName, appState),
                  _buildAvailabilityCard(),
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Header ──────────────────────────────────────────────────────────
  Widget _buildHeader(String displayName, AppState appState) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + logout
          Row(
            children: [
              // Pulsing avatar
              ScaleTransition(
                scale: _isAudioOn ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isAudioOn ? AppColors.successGreen : Colors.white38,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    backgroundImage: appState.selectedAvatar.isNotEmpty
                        ? AssetImage(appState.selectedAvatar)
                        : const AssetImage('assets/avatars/female_1.png'),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $displayName 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isAudioOn
                                ? AppColors.successGreen
                                : Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isAudioOn
                              ? 'Online · Ready for calls'
                              : 'Offline · Not receiving calls',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isAudioOn
                                ? Colors.greenAccent.shade100
                                : Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Balance pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '₹${_redeemableBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),

        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 32, color: Colors.white24);
  }

  // ── 2. Availability Card ───────────────────────────────────────────────
  Widget _buildAvailabilityCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.lightBlueBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: AppColors.primaryBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.wifi_tethering,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Availability Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          // Audio toggle
          Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isAudioOn
                    ? AppColors.successGreen.withValues(alpha: 0.08)
                    : AppColors.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isAudioOn
                      ? AppColors.successGreen.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Icon with animated bg
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isAudioOn
                          ? AppColors.successGreen.withValues(alpha: 0.15)
                          : AppColors.lightBlueBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isAudioOn ? Icons.phone_in_talk : Icons.phone_disabled,
                      color: _isAudioOn
                          ? AppColors.successGreen
                          : AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Audio Calls',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        const SizedBox(height: 2),
                        Text(
                          _isAudioOn
                              ? 'You are receiving calls'
                              : 'Turn on to receive calls',
                          style: TextStyle(
                              fontSize: 12,
                              color: _isAudioOn
                                  ? AppColors.successGreen
                                  : AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  // Switch
                  Switch(
                    value: _isAudioOn,
                    activeTrackColor: AppColors.successGreen,
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor:
                        AppColors.textGrey.withValues(alpha: 0.3),
                    onChanged: (val) => _updateOnlineStatus(val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Stats Card ──────────────────────────────────────────────────────
  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.lightBlueBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: AppColors.primaryBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Total Activity",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _fetchExpertStats,
                  child: const Icon(Icons.refresh_rounded,
                      color: AppColors.primaryBlue, size: 20),
                ),
              ],
            ),
          ),

          if (_isLoadingStats)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Stats Row
                  Row(
                    children: [
                      // Talktime stat
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.timer_outlined,
                          iconColor: AppColors.primaryBlue,
                          value: '$_totalTalktimeMinutes m',
                          label: 'Total Talktime',
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Balance stat
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: AppColors.successGreen,
                          value:
                              '₹${_redeemableBalance.toStringAsFixed(0)}',
                          label: 'Redeemable Balance',
                          valueColor: AppColors.successGreen,
                          trailing: Tooltip(
                            message:
                                'Amount available after platform fee deduction.',
                            child: const Icon(Icons.info_outline,
                                size: 14, color: AppColors.textGrey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Withdraw button
                  GestureDetector(
                    onTap: _showWithdrawDialog,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: AppColors.primaryBlue, width: 1.5),
                        gradient: _redeemableBalance > 0
                            ? const LinearGradient(
                                colors: [
                                  AppColors.primaryBlue,
                                  Color(0xFF1565C0)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: _redeemableBalance > 0
                            ? null
                            : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_rounded,
                            size: 18,
                            color: _redeemableBalance > 0
                                ? Colors.white
                                : AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Withdraw',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _redeemableBalance > 0
                                  ? Colors.white
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ],
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

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    Color valueColor = AppColors.textDark,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.lightBlueBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing,
              ]
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
