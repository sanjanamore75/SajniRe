import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
import '../models/female_expert.dart';
import '../providers/app_state.dart';
import '../services/call_service.dart';
import '../services/matching_service.dart';
import 'active_call_page.dart';

class MatchmakingScreen extends StatefulWidget {
  final FemaleExpert? requestedExpert;
  final bool isRandomMode;

  const MatchmakingScreen({
    super.key,
    this.requestedExpert,
    this.isRandomMode = false,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  final CallService _callService = CallService();
  late final MatchingService _matchingService;
  MatchController? _matchController;
  
  String _statusMessage = 'Connecting...';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService(_callService);
    
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startMatchmakingProcess();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _radarController.dispose();
    _matchController?.cancel();
    super.dispose();
  }

  Future<void> _startMatchmakingProcess() async {
    // 1. Initial short delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 600));
    if (_isDisposed) return;

    final appState = context.read<AppState>();
    final String callerId = appState.nickname.isNotEmpty 
        ? appState.nickname.toLowerCase() 
        : 'caller_1';
    final hasUsedFreeCall = appState.hasUsedFreeCall;

    // 2. Direct Call Check (if not random mode)
    if (!widget.isRandomMode && widget.requestedExpert != null) {
      setState(() {
        _statusMessage = 'Checking availability for ${widget.requestedExpert!.nickname}...';
      });

      bool isBusy = true;
      try {
        final expertId = widget.requestedExpert!.nickname.toLowerCase();
        final docSnap = await FirebaseDatabase.instanceFor(
            app: FirebaseDatabase.instance.app,
            databaseURL: 'https://eluelu-88a6c-default-rtdb.asia-southeast1.firebasedatabase.app',
          ).ref('experts_queue/$expertId')
            .get();

        if (docSnap.exists) {
          final data = Map<dynamic, dynamic>.from(docSnap.value as Map);
          if (data['status'] == 'waiting') {
            isBusy = false;
          }
        }
      } catch (e) {
        debugPrint('Error checking availability: $e');
      }

      if (_isDisposed) return;

      if (!isBusy) {
        // Connect directly!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveCallPage(
              receiverId: widget.requestedExpert!.nickname.toLowerCase(),
              callerId: callerId,
              nickname: widget.requestedExpert!.nickname,
              avatarPath: widget.requestedExpert!.avatarPath,
              pricePerMin: widget.requestedExpert!.pricePerMin.toDouble(),
              isCaller: true,
              isFirstFreeCall: !hasUsedFreeCall,
            ),
          ),
        );
        return;
      } else {
        // Fallback to random matchmaking
        setState(() {
          _statusMessage = '${widget.requestedExpert!.nickname} is busy.\nFinding the best match...';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (_isDisposed) return;
      }
    }

    // 3. Execute Random Matchmaking
    setState(() {
      _statusMessage = 'Looking for the best expert...';
    });

    _matchController = _matchingService.findRandomExpertAndCall(
      callerId: callerId,
      onMatchFound: (expertId, callRoomId) {
        if (_isDisposed) return;
        
        // Fetch expert details before routing
        FirebaseFirestore.instance
            .collection('experts')
            .doc(expertId)
            .get()
            .then((doc) {
              if (_isDisposed) return;
              
              String nickname = expertId.toUpperCase();
              String avatarPath = 'assets/avatars/female_1.png';
              double pricePerMin = 5.0;

              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                nickname = data['nickname'] ?? nickname;
                avatarPath = data['avatarPath'] ?? avatarPath;
                pricePerMin = (data['pricePerMin'] as num?)?.toDouble() ?? 5.0;
              }

              Navigator.pushReplacement(
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
            });
      },
      onRemoteStream: (stream) {},
      onCallEnded: () {},
      onError: (err) {
        if (_isDisposed) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Matchmaking error: $err')),
        );
        Navigator.pop(context);
      },
    );
  }

  void _cancelSearch() {
    _matchController?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate background
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // Radar Animation
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Expanding rings
                  AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: List.generate(3, (index) {
                          final delay = index * 0.33;
                          double progress = (_radarController.value + delay) % 1.0;
                          return Transform.scale(
                            scale: 1.0 + (progress * 2.5),
                            child: Opacity(
                              opacity: (1.0 - progress).clamp(0.0, 1.0),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFF43F5E), // Rose accent
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  
                  // Center Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B), // Slate 800
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withOpacity(0.5),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Status Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Cancel Button
            GestureDetector(
              onTap: _cancelSearch,
              child: Container(
                margin: const EdgeInsets.only(bottom: 40),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Cancel Search',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
