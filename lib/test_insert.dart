import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseFirestore.instance.collection('experts').doc('dummy_expert').set({
    'nickname': 'Dummy Server',
    'isOnline': true,
    'city': 'Delhi',
    'pricePerMin': 10,
    'categories': ['All'],
  });
  print('Dummy expert inserted!');
}
