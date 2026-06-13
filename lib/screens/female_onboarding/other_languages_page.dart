import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

class OtherLanguagesPage extends StatefulWidget {
  final VoidCallback onNext;
  const OtherLanguagesPage({super.key, required this.onNext});

  @override
  State<OtherLanguagesPage> createState() => _OtherLanguagesPageState();
}

class _OtherLanguagesPageState extends State<OtherLanguagesPage> {
  final List<String> _availableLanguages = [
    'English',
    'Kannada',
    'Gujarati',
    'Marathi',
    'Rajasthani',
    'Tamil',
    'Punjabi',
    'Malayalam',
    'Bhojpuri',
    'Odia',
  ];

  late List<String> _selectedLanguages;

  @override
  void initState() {
    super.initState();
    _selectedLanguages = List.from(context.read<AppState>().otherLanguages);
  }

  void _submit() {
    final appState = context.read<AppState>();
    appState.clearOtherLanguages();
    for (var lang in _selectedLanguages) {
      appState.toggleOtherLanguage(lang);
    }
    widget.onNext();
  }

  void _skip() {
    // Clear and go to next
    context.read<AppState>().clearOtherLanguages();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        const Text(
          'Select other',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey,
          ),
        ),
        const Text(
          'Languages',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textBlack,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose languages you can speak comfortably.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textGrey,
          ),
        ),
        const SizedBox(height: 30),

        // Grid/Wrap of options
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableLanguages.map((lang) {
                final isSelected = _selectedLanguages.contains(lang);
                return FilterChip(
                  label: Text(
                    lang,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textBlack,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryBlue,
                  checkmarkColor: Colors.white,
                  backgroundColor: AppTheme.inputBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.borderGrey,
                      width: 1.0,
                    ),
                  ),

                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedLanguages.add(lang);
                      } else {
                        _selectedLanguages.remove(lang);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),

        // Action Buttons
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: _skip,
              child: const Text(
                'Skip this step',
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
