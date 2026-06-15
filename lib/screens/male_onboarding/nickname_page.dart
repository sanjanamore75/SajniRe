import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

class NicknamePage extends StatefulWidget {
  final VoidCallback onNext;
  const NicknamePage({super.key, required this.onNext});

  @override
  State<NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<NicknamePage> {
  final TextEditingController _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nicknameController.text = context.read<AppState>().nickname;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AppState>().setNickname(_nicknameController.text.trim());
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'What is your',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGrey,
            ),
          ),
          const Text(
            'Nickname?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textBlack,
            ),
          ),
          const SizedBox(height: 40),

          // Input field
          TextFormField(
            controller: _nicknameController,
            autofocus: true,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textBlack,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter nickname',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your nickname';
              }
              if (value.trim().length < 2) {
                return 'Nickname must be at least 2 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const Spacer(),

          // Next button
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
