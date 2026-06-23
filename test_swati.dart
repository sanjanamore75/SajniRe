import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('experts').get();
  print('Total experts: ${snapshot.docs.length}');
  for (var doc in snapshot.docs) {
    print('Expert: ${doc.id}');
    print('  nickname: ${doc.data()['nickname']}');
    print('  isOnline: ${doc.data()['isOnline']}');
    print('  categories: ${doc.data()['categories']}');
  }
}
