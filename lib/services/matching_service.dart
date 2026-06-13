import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_service.dart';

/// Controller to handle and abort matching sessions.
class MatchController {
  StreamSubscription? _subscription;
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
    _subscription?.cancel();
  }

  bool get isCancelled => _isCancelled;
}

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CallService _callService;

  MatchingService(this._callService);

  CallService get callService => _callService;

  /// Female Expert Logic (Joining the Queue)
  Future<void> setExpertOnlineStatus(String expertId, bool isOnline) async {
    try {
      final docRef = _firestore.collection('experts_queue').doc(expertId);
      if (isOnline) {
        await docRef.set({
          'expertId': expertId,
          'status': 'waiting',
          'timestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('Expert $expertId added/updated in experts_queue.');
      } else {
        await docRef.delete();
        debugPrint('Expert $expertId removed from experts_queue.');
      }
    } catch (e) {
      debugPrint('Error setting expert online status: $e');
      rethrow;
    }
  }

  /// Male Caller Logic (The Random Match Algorithm)
  MatchController findRandomExpertAndCall({
    required String callerId,
    required Function(String expertId, String callRoomId) onMatchFound,
    required Function(MediaStream stream) onRemoteStream,
    required Function() onCallEnded,
    required Function(dynamic error) onError,
  }) {
    final controller = MatchController();

    _executeMatching(
      callerId: callerId,
      controller: controller,
      onMatchFound: onMatchFound,
      onRemoteStream: onRemoteStream,
      onCallEnded: onCallEnded,
      onError: onError,
    );

    return controller;
  }

  Future<void> _executeMatching({
    required String callerId,
    required MatchController controller,
    required Function(String expertId, String callRoomId) onMatchFound,
    required Function(MediaStream stream) onRemoteStream,
    required Function() onCallEnded,
    required Function(dynamic error) onError,
  }) async {
    try {
      // 1. Check if an expert is already waiting
      final querySnapshot = await _firestore
          .collection('experts_queue')
          .where('status', isEqualTo: 'waiting')
          .get();

      if (controller.isCancelled) return;

      if (querySnapshot.docs.isNotEmpty) {
        // Sort waiting experts in memory by oldest timestamp to avoid index creation issues
        final docs = List<QueryDocumentSnapshot>.from(querySnapshot.docs);
        docs.sort((a, b) {
          final tA = a.get('timestamp') as Timestamp?;
          final tB = b.get('timestamp') as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tA.compareTo(tB);
        });

        for (var doc in docs) {
          if (controller.isCancelled) return;
          final expertId = doc.id;
          final locked = await _lockExpertInTransaction(expertId, callerId);
          if (locked) {
            try {
              final roomId = await _callService.startCall(
                expertId: expertId,
                callerId: callerId,
                onRemoteStream: onRemoteStream,
                onCallEnded: onCallEnded,
              );
              if (!controller.isCancelled) {
                onMatchFound(expertId, roomId);
                return;
              } else {
                // Cancelled during setup, clean up
                await _callService.endCall(roomId);
                await _unlockExpert(expertId);
                return;
              }
            } catch (e) {
              await _unlockExpert(expertId);
              onError(e);
              return;
            }
          }
        }
      }

      // 2. If no expert found, subscribe to experts_queue updates
      if (controller.isCancelled) return;

      final subscription = _firestore
          .collection('experts_queue')
          .where('status', isEqualTo: 'waiting')
          .snapshots()
          .listen((snapshot) async {
        if (controller.isCancelled) return;

        final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
        docs.sort((a, b) {
          final tA = a.get('timestamp') as Timestamp?;
          final tB = b.get('timestamp') as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tA.compareTo(tB);
        });

        for (var doc in docs) {
          if (controller.isCancelled) return;
          final expertId = doc.id;
          final locked = await _lockExpertInTransaction(expertId, callerId);
          if (locked) {
            controller.cancel(); // Stop listening
            try {
              final roomId = await _callService.startCall(
                expertId: expertId,
                callerId: callerId,
                onRemoteStream: onRemoteStream,
                onCallEnded: onCallEnded,
              );
              if (!controller.isCancelled) {
                onMatchFound(expertId, roomId);
              } else {
                await _callService.endCall(roomId);
                await _unlockExpert(expertId);
              }
            } catch (e) {
              await _unlockExpert(expertId);
              onError(e);
            }
            return;
          }
        }
      }, onError: (err) {
        if (!controller.isCancelled) {
          onError(err);
        }
      });

      controller._subscription = subscription;
    } catch (e) {
      if (!controller.isCancelled) {
        onError(e);
      }
    }
  }

  Future<void> _unlockExpert(String expertId) async {
    try {
      await _firestore.collection('experts_queue').doc(expertId).update({
        'status': 'waiting',
        'lockedBy': FieldValue.delete(),
        'lockedAt': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error unlocking expert $expertId: $e');
    }
  }

  Future<bool> _lockExpertInTransaction(String expertId, String callerId) async {
    try {
      final docRef = _firestore.collection('experts_queue').doc(expertId);
      final locked = await _firestore.runTransaction<bool>((transaction) async {
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) return false;

        final data = docSnap.data();
        if (data != null && data['status'] == 'waiting') {
          transaction.update(docRef, {
            'status': 'in_call',
            'lockedBy': callerId,
            'lockedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
        return false;
      });
      return locked;
    } catch (e) {
      debugPrint('Transaction error locking expert $expertId: $e');
      return false;
    }
  }
}
