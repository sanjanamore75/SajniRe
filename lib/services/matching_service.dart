import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
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
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: 'https://eluelu-88a6c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  final CallService _callService;

  MatchingService(this._callService);

  CallService get callService => _callService;

  /// Female Expert Logic (Joining the Queue)
  Future<void> setExpertOnlineStatus(String expertId, bool isOnline) async {
    try {
      final docRef = _database.ref('experts_queue/$expertId');
      if (isOnline) {
        await docRef.set({
          'expertId': expertId,
          'status': 'waiting',
          'timestamp': ServerValue.timestamp,
        });
        debugPrint('Expert $expertId added/updated in experts_queue.');
      } else {
        await docRef.remove();
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
      final querySnapshot = await _database
          .ref('experts_queue')
          .orderByChild('status')
          .equalTo('waiting')
          .get();

      if (controller.isCancelled) return;

      if (querySnapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(querySnapshot.value as Map);
        final docs = data.entries.toList();

        // Sort waiting experts in memory by oldest timestamp
        docs.sort((a, b) {
          final tA = a.value['timestamp'] is int ? a.value['timestamp'] as int : 0;
          final tB = b.value['timestamp'] is int ? b.value['timestamp'] as int : 0;
          return tA.compareTo(tB);
        });

        for (var doc in docs) {
          if (controller.isCancelled) return;
          final expertId = doc.key as String;
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

      final subscription = _database
          .ref('experts_queue')
          .orderByChild('status')
          .equalTo('waiting')
          .onValue
          .listen((event) async {
        if (controller.isCancelled) return;

        if (event.snapshot.value == null) return;
        
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final docs = data.entries.toList();

        docs.sort((a, b) {
          final tA = a.value['timestamp'] is int ? a.value['timestamp'] as int : 0;
          final tB = b.value['timestamp'] is int ? b.value['timestamp'] as int : 0;
          return tA.compareTo(tB);
        });

        for (var doc in docs) {
          if (controller.isCancelled) return;
          final expertId = doc.key as String;
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
      await _database.ref('experts_queue/$expertId').update({
        'status': 'waiting',
        'lockedBy': null,
        'lockedAt': null,
      });
    } catch (e) {
      debugPrint('Error unlocking expert $expertId: $e');
    }
  }

  Future<bool> _lockExpertInTransaction(String expertId, String callerId) async {
    try {
      final docRef = _database.ref('experts_queue/$expertId');
      final TransactionResult result = await docRef.runTransaction((Object? post) {
        if (post == null) {
          return Transaction.abort();
        }
        Map<String, dynamic> data = Map<String, dynamic>.from(post as Map);
        if (data['status'] == 'waiting') {
          data['status'] = 'in_call';
          data['lockedBy'] = callerId;
          data['lockedAt'] = ServerValue.timestamp;
          return Transaction.success(data);
        }
        return Transaction.abort();
      });
      return result.committed;
    } catch (e) {
      debugPrint('Transaction error locking expert $expertId: $e');
      return false;
    }
  }
}
