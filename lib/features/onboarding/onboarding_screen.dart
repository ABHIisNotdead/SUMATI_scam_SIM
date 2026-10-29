import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _finishOnboarding() async {
    await ref.read(preferencesProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/');
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(preferencesProvider).appLanguage;
    final isLastPage = _currentPage == 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Page Indicators and Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer to balance Skip button
                  // Page Indicators (4 pages total)
                  Row(
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppTheme.primaryTeal : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      isLastPage || _currentPage == 0 ? '' : UiStrings.get(currentLang, 'skip'),
                      style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable PageView (4 Pages)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // Page 0: Language Selection (FIRST)
                  _buildLanguageSelectionPage(currentLang),

                  // Page 1: Welcome
                  _buildFeaturePage(
                    icon: Icons.verified_user_rounded,
                    iconColor: const Color(0xFF0F4C5C),
                    title: UiStrings.get(currentLang, 'welcome_title'),
                    subtitle: UiStrings.get(currentLang, 'welcome_sub'),
                    description: UiStrings.get(currentLang, 'welcome_desc'),
                  ),

                  // Page 2: Realistic Practice
                  _buildFeaturePage(
                    icon: Icons.phone_in_talk_rounded,
                    iconColor: const Color(0xFFFB8500),
                    title: UiStrings.get(currentLang, 'realistic_title'),
                    subtitle: UiStrings.get(currentLang, 'realistic_sub'),
                    description: UiStrings.get(currentLang, 'realistic_desc'),
                  ),

                  // Page 3: Track Safety
                  _buildFeaturePage(
                    icon: Icons.family_restroom_rounded,
                    iconColor: const Color(0xFF2E7D32),
                    title: UiStrings.get(currentLang, 'track_title'),
                    subtitle: UiStrings.get(currentLang, 'track_sub'),
                    description: UiStrings.get(currentLang, 'track_desc'),
                  ),
                ],
              ),
            ),

            // Bottom Navigation Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ElevatedButton.icon(
                onPressed: _nextPage,
                icon: Icon(
                  isLastPage ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                  size: 24,
                ),
                label: Text(
                  isLastPage
                      ? UiStrings.get(currentLang, 'get_started')
                      : UiStrings.get(currentLang, 'next'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  backgroundColor: isLastPage ? const Color(0xFF2E7D32) : AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 0: Dedicated Senior-Friendly Language Selector
  Widget _buildLanguageSelectionPage(String currentLang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3), width: 3),
            ),
            child: const Icon(Icons.language_rounded, size: 54, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 20),
          Text(
            UiStrings.get(currentLang, 'choose_language'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            UiStrings.get(currentLang, 'choose_language_sub'),
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // English Card
          _buildLanguageOptionCard(
            langCode: 'en',
            flag: '🇬🇧',
            title: 'English',
            subtitle: 'Simple English for seniors',
            isSelected: currentLang == 'en',
          ),
          const SizedBox(height: 14),

          // Hindi Card
          _buildLanguageOptionCard(
            langCode: 'hi',
            flag: '🇮🇳',
            title: 'हिंदी (Hindi)',
            subtitle: 'सरल और सुरक्षित हिंदी',
            isSelected: currentLang == 'hi',
          ),
          const SizedBox(height: 14),

          // Marathi Card
          _buildLanguageOptionCard(
            langCode: 'mr',
            flag: '🇮🇳',
            title: 'मराठी (Marathi)',
            subtitle: 'सोपे आणि सुरक्षित मराठी',
            isSelected: currentLang == 'mr',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard({
    required String langCode,
    required String flag,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 3 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(preferencesProvider.notifier).setLanguage(langCode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade300,
              width: isSelected ? 2.5 : 1,
            ),
            color: isSelected ? AppTheme.primaryTeal.withValues(alpha: 0.05) : Colors.white,
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primaryTeal : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade400,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Feature Explanation Page Template
  Widget _buildFeaturePage({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Giant Feature Icon
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Icon(icon, size: 70, color: iconColor),
          ),
          const SizedBox(height: 28),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Description
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 17,
                height: 1.5,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
