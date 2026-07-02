import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  print('=== ALL EXPERTS IN FIRESTORE ===');
  final experts = await FirebaseFirestore.instance.collection('experts').get();
  for (var doc in experts.docs) {
    final data = doc.data();
    print('------ DOC: ${doc.id} ------');
    print('  nickname: ${data['nickname']}');
    print('  uid: ${data['uid']}');
    print('  isOnline: ${data['isOnline']}');
    print('  ALL FIELDS: $data');
  }
  print('DONE');
}
