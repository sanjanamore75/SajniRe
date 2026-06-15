import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../male_dashboard_screen.dart';

class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});

  @override
  State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  String _selectedAvatar = '';
  bool _isSaving = false;

  final List<String> _avatars = [
    'assets/avatars/male_1.png',
    'assets/avatars/male_2.png',
    'assets/avatars/male_3.png',
    'assets/avatars/male_4.png',
    'assets/avatars/male_5.png',
    'assets/avatars/male_6.png',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = context.read<AppState>().selectedAvatar;
    // Default to the first avatar if none is selected
    if (_selectedAvatar.isEmpty || !_avatars.contains(_selectedAvatar)) {
      _selectedAvatar = _avatars[0];
    }
  }

  void _submit() async {
    if (_selectedAvatar.isEmpty || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final appState = context.read<AppState>();
    appState.setSelectedAvatar(_selectedAvatar);

    final mobile = appState.mobileNumber.isNotEmpty ? appState.mobileNumber : "test_mobile";
    final nickname = appState.nickname.isNotEmpty ? appState.nickname : "User";

    try {
      // Save profile info to Firestore under 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(mobile).set({
        'mobileNumber': mobile,
        'nickname': nickname,
        'avatarPath': _selectedAvatar,
        'gender': 'male',
        'walletBalance': appState.walletBalance,
        'hasUsedFreeCall': appState.hasUsedFreeCall,
      }, SetOptions(merge: true));

      if (mounted) {
        // Navigate to MaleCallerDashboard and clear the navigation stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MaleCallerDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        const Text(
          'Choose your',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey,
          ),
        ),
        const Text(
          'Profile Avatar',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textBlack,
          ),
        ),
        const SizedBox(height: 30),

        // Grid of Avatars
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.0,
            ),
            itemCount: _avatars.length,
            itemBuilder: (context, index) {
              final avatar = _avatars[index];
              final isSelected = _selectedAvatar == avatar;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatar = avatar;
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 70,
                        backgroundColor: AppTheme.inputBg,
                        backgroundImage: AssetImage(avatar),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Next button / Loader
        ElevatedButton(
          onPressed: _selectedAvatar.isNotEmpty && !_isSaving ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedAvatar.isNotEmpty
                ? AppTheme.primaryBlue
                : const Color(0xFFCCCCCC),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Next'),
        ),
      ],
    );
  }
}
