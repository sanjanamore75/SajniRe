import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final experts = await FirebaseFirestore.instance.collection('experts').get();
  for (var doc in experts.docs) {
    if (!doc.data().containsKey('createdAt')) {
      print('Updating expert ${doc.id} with missing createdAt field');
      await doc.reference.update({
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
  print('Done updating experts.');
}
