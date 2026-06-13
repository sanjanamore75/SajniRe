import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';

class BirthYearPage extends StatefulWidget {
  final VoidCallback onNext;
  const BirthYearPage({super.key, required this.onNext});

  @override
  State<BirthYearPage> createState() => _BirthYearPageState();
}

class _BirthYearPageState extends State<BirthYearPage> {
  late int _selectedYear;
  final List<int> _years = List.generate(41, (index) => 1980 + index); // 1980 to 2020

  @override
  void initState() {
    super.initState();
    _selectedYear = context.read<AppState>().birthYear;
  }

  void _submit() {
    context.read<AppState>().setBirthYear(_selectedYear);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    // Find index of current selected year in our list
    final initialIndex = _years.indexOf(_selectedYear);
    final scrollController = FixedExtentScrollController(
      initialItem: initialIndex != -1 ? initialIndex : 21, // default to 2001 (index 21)
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        const Text(
          'Select your',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: AppTheme.textGrey,
          ),
        ),
        const Text(
          'Birth Year',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textBlack,
          ),
        ),
        const SizedBox(height: 40),

        // Cupertino Scrollable Picker
        Expanded(
          child: Center(
            child: SizedBox(
              height: 250,
              child: CupertinoPicker(
                scrollController: scrollController,
                itemExtent: 50,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedYear = _years[index];
                  });
                },
                children: _years.map((year) {
                  final isSelected = year == _selectedYear;
                  return Center(
                    child: Text(
                      year.toString(),
                      style: TextStyle(
                        fontSize: isSelected ? 26 : 20,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.textGrey,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Next button
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
