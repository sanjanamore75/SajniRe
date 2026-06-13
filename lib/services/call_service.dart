import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Active listeners/subscriptions for call room updates
  final List<StreamSubscription> _subscriptions = [];

  // Dynamic listeners that can be updated after startCall/acceptCall
  Function(MediaStream stream)? onRemoteStreamListener;
  Function()? onCallEndedListener;

  /// Update the active call callbacks dynamically
  void updateListeners({
    Function(MediaStream stream)? onRemoteStream,
    Function()? onCallEnded,
  }) {
    if (onRemoteStream != null) {
      onRemoteStreamListener = onRemoteStream;
    }
    if (onCallEnded != null) {
      onCallEndedListener = onCallEnded;
    }
  }

  // WebRTC ICE Configuration using Google's free STUN servers
  final Map<String, dynamic> _iceConfiguration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ]
      },
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp'
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      }
    ],
    'sdpSemantics': 'unified-plan'
  };

  // Getters
  RTCPeerConnection? get peerConnection => _peerConnection;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Listen for incoming calls for an expert.
  /// Trigger [onCallReceived] when another user creates a call with status 'calling'.
  StreamSubscription<QuerySnapshot> listenForIncomingCalls({
    required String expertId,
    required Function(String callRoomId, String callerId) onCallReceived,
  }) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: expertId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final callRoomId = change.doc.id;
            final callerId = data['callerId'] ?? 'unknown';
            onCallReceived(callRoomId, callerId);
          }
        }
      }
    }, onError: (e) {
      debugPrint('Error listening for incoming calls: $e');
    });
  }

  /// Caller (Male Caller) initiates the call
  Future<String> startCall({
    required String expertId,
    required String callerId,
    required Function(MediaStream stream) onRemoteStream,
    required Function() onCallEnded,
  }) async {
    onRemoteStreamListener = onRemoteStream;
    onCallEndedListener = onCallEnded;
    try {
      // 1. Initialize local media audio track
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // 2. Create peer connection
      _peerConnection = await createPeerConnection(_iceConfiguration);

      // 3. Add local track to connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. Listen for remote track / audio streams
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          onRemoteStreamListener?.call(_remoteStream!);
        }
      };
      _peerConnection!.onAddStream = (MediaStream stream) {
        _remoteStream = stream;
        onRemoteStreamListener?.call(_remoteStream!);
      };

      // 5. Create call document in Firestore
      final DocumentReference roomRef = _firestore.collection('calls').doc();
      final String roomId = roomRef.id;

      // 6. Handle local ICE candidates and upload them
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          roomRef.collection('callerCandidates').add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      };

      // 7. Generate SDP Offer
      final RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // 8. Upload SDP Offer to call document
      await roomRef.set({
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
        'callerId': callerId,
        'receiverId': expertId,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

      bool remoteDescriptionSet = false;
      final List<RTCIceCandidate> pendingRemoteCandidates = [];

      // 9. Subscribe to call document updates to catch SDP Answer
      final roomSub = roomRef.snapshots().listen((snapshot) async {
        if (!snapshot.exists) {
          onCallEndedListener?.call();
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) return;

        // Check if call was ended remotely
        if (data['status'] == 'ended') {
          onCallEndedListener?.call();
          return;
        }

        // Set Remote Description when answer is received
        if (data['answer'] != null && !remoteDescriptionSet) {
          remoteDescriptionSet = true;
          final answerMap = data['answer'];
          final description = RTCSessionDescription(
            answerMap['sdp'],
            answerMap['type'],
          );
          await _peerConnection!.setRemoteDescription(description);

          // Add all queued remote candidates
          for (var candidate in pendingRemoteCandidates) {
            await _peerConnection!.addCandidate(candidate);
          }
          pendingRemoteCandidates.clear();
        }
      });
      _subscriptions.add(roomSub);

      // 10. Subscribe to remote ICE candidates (expertCandidates)
      final candidatesSub = roomRef
          .collection('expertCandidates')
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && _peerConnection != null) {
              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              );
              if (remoteDescriptionSet) {
                await _peerConnection!.addCandidate(candidate);
              } else {
                pendingRemoteCandidates.add(candidate);
              }
            }
          }
        }
      });
      _subscriptions.add(candidatesSub);

      return roomId;
    } catch (e) {
      debugPrint('Error starting WebRTC call: $e');
      await disposeCall();
      rethrow;
    }
  }

  /// Receiver (Female Expert) accepts the incoming call
  Future<void> acceptCall({
    required String callRoomId,
    required Function(MediaStream stream) onRemoteStream,
    required Function() onCallEnded,
  }) async {
    onRemoteStreamListener = onRemoteStream;
    onCallEndedListener = onCallEnded;
    try {
      final DocumentReference roomRef = _firestore.collection('calls').doc(callRoomId);
      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) {
        throw Exception('Call room not found');
      }

      final roomData = roomSnapshot.data() as Map<String, dynamic>;
      final offerMap = roomData['offer'];
      if (offerMap == null) {
        throw Exception('No SDP Offer found in room');
      }

      // 1. Initialize local media audio track
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // 2. Create peer connection
      _peerConnection = await createPeerConnection(_iceConfiguration);

      // 3. Add local track to connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. Listen for remote track / audio streams
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          onRemoteStreamListener?.call(_remoteStream!);
        }
      };
      _peerConnection!.onAddStream = (MediaStream stream) {
        _remoteStream = stream;
        onRemoteStreamListener?.call(_remoteStream!);
      };

      // 5. Handle local ICE candidates and upload them
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          roomRef.collection('expertCandidates').add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      };

      // 6. Set Remote Description (SDP Offer)
      final RTCSessionDescription remoteDescription = RTCSessionDescription(
        offerMap['sdp'],
        offerMap['type'],
      );
      await _peerConnection!.setRemoteDescription(remoteDescription);

      // 7. Generate SDP Answer
      final RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // 8. Update Firestore document with SDP Answer and change status to connected
      await roomRef.update({
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'status': 'connected',
      });

      // 9. Subscribe to call document updates to monitor ended state
      final roomSub = roomRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) {
          onCallEndedListener?.call();
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) return;

        if (data['status'] == 'ended') {
          onCallEndedListener?.call();
        }
      });
      _subscriptions.add(roomSub);

      // 10. Subscribe to remote ICE candidates (callerCandidates)
      final candidatesSub = roomRef
          .collection('callerCandidates')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && _peerConnection != null) {
              _peerConnection!.addCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            }
          }
        }
      });
      _subscriptions.add(candidatesSub);
    } catch (e) {
      debugPrint('Error accepting WebRTC call: $e');
      await disposeCall();
      rethrow;
    }
  }

  /// Hangs up and clean up WebRTC resources and deletes the Firestore call document
  Future<void> endCall(String callRoomId) async {
    try {
      final DocumentReference roomRef = _firestore.collection('calls').doc(callRoomId);
      
      // Update room status to ended and delete document
      await roomRef.update({'status': 'ended'});
      
      // Delete subcollections to avoid database bloat
      await _deleteCollection(roomRef.collection('callerCandidates'));
      await _deleteCollection(roomRef.collection('expertCandidates'));
      await roomRef.delete();
    } catch (e) {
      debugPrint('Error ending call document: $e');
    } finally {
      await disposeCall();
    }
  }

  /// Cleans up local media streams, peer connections, and cancels active listeners
  Future<void> disposeCall() async {
    // Cancel all Firestore stream subscriptions
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Stop and dispose local stream tracks
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    _remoteStream = null;

    // Close peer connection
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
  }

  /// Helper helper to delete all documents in a subcollection
  Future<void> _deleteCollection(CollectionReference collection) async {
    final snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
