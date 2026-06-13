import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'gender_selection_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final PageController _bannerController = PageController();
  int _currentBannerPage = 0;
  Timer? _bannerTimer;

  final List<Map<String, dynamic>> _bannerSlides = [
    {
      'icon': Icons.favorite_rounded,
      'title': 'Real Connections',
      'subtitle': 'Find your perfect companion & talk with experts instantly.',
    },
    {
      'icon': Icons.security_rounded,
      'title': '100% Safe & Secure',
      'subtitle': 'Your privacy is our priority. Talk securely and anonymously.',
    },
    {
      'icon': Icons.phone_in_talk_rounded,
      'title': 'Instant Audio Calls',
      'subtitle': 'Connect directly with experts starting at just ₹5/min.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startBannerAutoPlay();
  }

  void _startBannerAutoPlay() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        int nextPage = _currentBannerPage + 1;
        if (nextPage >= _bannerSlides.length) {
          nextPage = 0;
        }
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _onGetOtpPressed() {
    if (_formKey.currentState!.validate()) {
      // Save phone number in Provider
      context.read<AppState>().setMobileNumber(_phoneController.text.trim());
      // Navigate to Gender Selection Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GenderSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'SajniRe!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.yellowtail(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue,
                                  Color(0xFFE2859B), // Soft rose/pink matching the logo's warmth
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: PageView.builder(
                              controller: _bannerController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentBannerPage = index;
                                });
                              },
                              itemCount: _bannerSlides.length,
                              itemBuilder: (context, index) {
                                final slide = _bannerSlides[index];
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          slide['icon'] as IconData,
                                          size: 64,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          slide['title'] as String,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          slide['subtitle'] as String,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Page Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_bannerSlides.length, (index) {
                              final isSelected = _currentBannerPage == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                width: isSelected ? 12.0 : 8.0,
                                height: 8.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: isSelected
                                      ? AppTheme.primaryBlue
                                      : AppTheme.primaryBlue.withValues(alpha: 0.3),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),

                      // Input and Action
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),
                            // Phone Number Field
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.inputBg,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: AppTheme.borderGrey,
                                  width: 1.0,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  // Country Prefix +91 Dropdown
                                  Row(
                                    children: [
                                      Image.network(
                                        'https://flagcdn.com/w40/in.png',
                                        width: 24,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.flag,
                                                  size: 24,
                                                ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '+91',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textBlack,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: AppTheme.textGrey,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    height: 24,
                                    width: 1,
                                    color: AppTheme.borderGrey,
                                  ),
                                  const SizedBox(width: 12),
                                  // Mobile input
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textBlack,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Your Mobile Number',
                                        hintStyle: TextStyle(
                                          color: AppTheme.textGrey,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter mobile number';
                                        }
                                        if (value.length < 10) {
                                          return 'Please enter a valid 10-digit number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Get OTP Button
                            ElevatedButton(
                              onPressed: _onGetOtpPressed,
                              child: const Text('Get OTP'),
                            ),
                            const SizedBox(height: 20),
                            // Footer Agreement Text
                            const Text(
                              'By tapping, you agree to our Terms of Use and Privacy Policy.\nAll your details are 100% safe & secure.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textGrey,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
