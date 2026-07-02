import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jaimakali/models/female_expert.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final mockIds = FemaleExpert.mockExperts.map((e) => e.id).toList();
  // Explicitly adding the one from Recents if needed by ID, but mockIds handles it

  final collection = FirebaseFirestore.instance.collection('experts');
  
  for (final id in mockIds) {
    try {
      await collection.doc(id).delete();
      print('Deleted $id from Firestore');
    } catch (e) {
      print('Error deleting $id: $e');
    }
  }

  print('Cleanup complete!');
}
