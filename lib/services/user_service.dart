import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream user profile based on their mobile number
  Stream<DocumentSnapshot> getUserProfile(String mobileNumber) {
    return _firestore.collection('users').doc(mobileNumber).snapshots();
  }

  // Update or Create user profile
  Future<void> updateUserProfile(String mobileNumber, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(mobileNumber).set(
        {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
}
