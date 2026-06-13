import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

class AvatarPage extends StatefulWidget {
  final VoidCallback onNext;
  const AvatarPage({super.key, required this.onNext});

  @override
  State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  String _selectedAvatar = '';
  
  final List<String> _avatars = [
    'assets/avatars/female_1.png',
    'assets/avatars/female_2.png',
    'assets/avatars/female_3.png',
    'assets/avatars/female_4.png',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = context.read<AppState>().selectedAvatar;
  }

  void _submit() {
    if (_selectedAvatar.isEmpty) return;
    context.read<AppState>().setSelectedAvatar(_selectedAvatar);
    widget.onNext();
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

        // 2x2 Grid of Avatars
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

        // Next button
        ElevatedButton(
          onPressed: _selectedAvatar.isNotEmpty ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedAvatar.isNotEmpty
                ? AppTheme.primaryBlue
                : const Color(0xFFCCCCCC),
          ),
          child: const Text('Next'),
        ),
      ],
    );
  }
}
