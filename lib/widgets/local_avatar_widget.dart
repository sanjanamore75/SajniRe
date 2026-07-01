import 'package:flutter/material.dart';

class LocalAvatarWidget extends StatelessWidget {
  final String uid;
  final String role; // 'expert' or 'user'
  final double radius;

  const LocalAvatarWidget({
    super.key,
    required this.uid,
    required this.role,
    this.radius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    String assetPath;
    
    if (uid.isEmpty) {
      assetPath = role == 'expert' ? 'assets/avatars/female_avatar.png' : 'assets/avatars/male_avatar.png';
    } else {
      int index = (uid.hashCode.abs() % 6) + 1;
      assetPath = role == 'expert' ? 'assets/avatars/female_$index.png' : 'assets/avatars/male_$index.png';
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: AssetImage(assetPath),
      backgroundColor: Colors.grey[200],
    );
  }
}
