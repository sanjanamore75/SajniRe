import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'nickname_page.dart';
import 'avatar_page.dart';

class MaleOnboardingParent extends StatefulWidget {
  const MaleOnboardingParent({super.key});

  @override
  State<MaleOnboardingParent> createState() => _MaleOnboardingParentState();
}

class _MaleOnboardingParentState extends State<MaleOnboardingParent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 2;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentPage + 1) / _totalPages;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _prevPage,
        ),
        title: Text(
          'Step ${_currentPage + 1} of $_totalPages',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Indicator
            Container(
              height: 4,
              width: double.infinity,
              color: AppTheme.inputBg,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: MediaQuery.of(context).size.width * progress,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Page Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Force sequential navigation
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    NicknamePage(onNext: _nextPage),
                    const AvatarPage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
