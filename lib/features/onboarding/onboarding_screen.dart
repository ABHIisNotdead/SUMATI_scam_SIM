import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/realistic_voice_service.dart';
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
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _speakCurrentPage(String lang) {
    String text = '';
    if (_currentPage == 0) {
      text = lang == 'hi'
          ? 'सुमति में आपका स्वागत है। अपनी पसंदीदा भाषा चुनें: अंग्रेजी, हिंदी, या मराठी।'
          : lang == 'mr'
              ? 'सुमती मध्ये आपले स्वागत आहे. तुमची पसंतीची भाषा निवडा: इंग्रजी, हिंदी, किंवा मराठी.'
              : 'Welcome to Sumati. Please select your preferred language: English, Hindi, or Marathi.';
    } else if (_currentPage == 1) {
      text = lang == 'hi'
          ? 'यह 100% सुरक्षित अभ्यास है। यहाँ कोई असली पैसे नहीं कटते। बिना डर के स्कैम कॉल और मैसेज पहचानना सीखें।'
          : lang == 'mr'
              ? 'हा १००% सुरक्षित सराव आहे. येथे कोणतेही खरे पैसे वापरले जात नाहीत. भीतीशिवाय फसवणूक ओळखायला शिका.'
              : 'This is a 100% safe simulation. No real money is ever used. Learn to detect scam calls and messages safely.';
    } else {
      text = lang == 'hi'
          ? 'परिवार हमेशा साथ। आपका परिवार आपकी सुरक्षा प्रगति और स्कोर देख सकता है।'
          : lang == 'mr'
              ? 'कुटुंब नेहमी सोबत. तुमचे कुटुंब तुमची सुरक्षा प्रगती पाहू शकते.'
              : 'Family connected. Your family members can view your safety score and progress.';
    }
    ref.read(realisticVoiceProvider).speakRealistic(text, lang);
  }

  @override
  void dispose() {
    ref.read(realisticVoiceProvider).stop();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Audio Speak Button & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Audio Listen Pill
                  InkWell(
                    onTap: () => _speakCurrentPage(currentLang),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.volume_up_rounded, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            UiStrings.get(currentLang, 'listen_aloud'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Skip Button
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      UiStrings.get(currentLang, 'skip'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View with 3 Clean Screens
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildLanguagePage(currentLang),
                  _buildSafeSimulationPage(currentLang),
                  _buildFamilyConnectPage(currentLang),
                ],
              ),
            ),

            // Bottom Navigation: Indicator Dots + Next/Start Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 3 Indicator Dots
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryContainer : const Color(0xFFD6DDD8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Get Started Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 54),
                        backgroundColor: AppTheme.primaryContainer,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == 2
                                ? UiStrings.get(currentLang, 'get_started')
                                : UiStrings.get(currentLang, 'next'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Clean, Minimal Language Selection ─────────────────────────────
  Widget _buildLanguagePage(String currentLang) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.translate_rounded, color: AppTheme.primary, size: 38),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              UiStrings.get(currentLang, 'choose_language'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              UiStrings.get(currentLang, 'choose_language_sub'),
              style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),

            // 3 Clean Language Cards
            _buildSimpleLanguageCard('en', '🇬🇧', 'English', 'Simple English with voice', currentLang),
            const SizedBox(height: 12),
            _buildSimpleLanguageCard('hi', '🇮🇳', 'हिंदी (Hindi)', 'सरल हिंदी और बोलकर सुनें', currentLang),
            const SizedBox(height: 12),
            _buildSimpleLanguageCard('mr', '🇮🇳', 'मराठी (Marathi)', 'सोपी मराठी आणि आवाज सहाय्य', currentLang),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLanguageCard(
    String code,
    String flag,
    String title,
    String subtitle,
    String currentLang,
  ) {
    final isSelected = currentLang == code;

    return Material(
      color: isSelected ? AppTheme.primaryFixed : AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 2 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ref.read(preferencesProvider.notifier).setLanguage(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryContainer : const Color(0xFFD6DDD8),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppTheme.primary.withValues(alpha: 0.8) : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppTheme.primaryContainer, size: 24)
              else
                const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Page 2: 100% Safe Simulator ──────────────────────────────────────────
  Widget _buildSafeSimulationPage(String currentLang) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2E7D32), size: 44),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              currentLang == 'hi'
                  ? '100% सुरक्षित अभ्यास'
                  : currentLang == 'mr'
                      ? '१००% सुरक्षित सराव'
                      : '100% Safe Simulator',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              currentLang == 'hi'
                  ? 'यहाँ कोई असली पैसे, बैंक खाता या असली कॉल का उपयोग नहीं होता। बिना किसी डर के खुलकर अभ्यास करें।'
                  : currentLang == 'mr'
                      ? 'येथे कोणतेही खरे पैसे किंवा बँक खाती वापरली जात नाहीत. भीतीशिवाय मुक्तपणे सराव करा.'
                      : 'No real money, bank accounts, or real calls are ever used. Practice online scam defense with zero risk.',
              style: const TextStyle(fontSize: 15, color: AppTheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Value prop bullets
            _buildFeatureBullet(
              Icons.phone_in_talk_rounded,
              currentLang == 'hi' ? 'नकली फोन कॉल' : 'Realistic Fake Calls',
              currentLang == 'hi' ? 'बैंक व पुलिस बनकर आने वाले फ्रॉड कॉल पहचानें' : 'Spot impostor bank and police calls safely',
              const Color(0xFF00875A),
            ),
            const SizedBox(height: 12),
            _buildFeatureBullet(
              Icons.chat_bubble_rounded,
              currentLang == 'hi' ? 'WhatsApp व SMS फ्रॉड' : 'WhatsApp & SMS Scams',
              currentLang == 'hi' ? 'फर्जी लॉटरी, बिल व पार्सल लिंक से बचें' : 'Detect fake lotteries, electricity bill threats & links',
              const Color(0xFF008069),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 3: Family Connect & Safety Score ─────────────────────────────────
  Widget _buildFamilyConnectPage(String currentLang) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.family_restroom_rounded, color: AppTheme.primary, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              currentLang == 'hi'
                  ? 'परिवार हमेशा साथ'
                  : currentLang == 'mr'
                      ? 'कुटुंब नेहमी सोबत'
                      : 'Family Guardian Connected',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              currentLang == 'hi'
                  ? 'जब भी आप किसी स्कैम से बचते हैं, आपका स्कोर बढ़ता है। आपके बच्चे और परिजन आपकी सुरक्षा देखकर निश्चिंत रह सकते हैं।'
                  : currentLang == 'mr'
                      ? 'प्रत्येक वेळी फसवणूक टाळल्यास तुमचा स्कोअर वाढतो. तुमचे कुटुंबीय तुमची सुरक्षा पाहू शकतात.'
                      : 'Track milestones on the Family Dashboard so loved ones can support and ensure your online safety.',
              style: const TextStyle(fontSize: 15, color: AppTheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD6DDD8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 36, color: AppTheme.primaryContainer),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentLang == 'hi' ? 'पारिवारिक लिंक कोड' : 'Family Connect Code',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'SUMATI-8421 • Tap to share',
                          style: TextStyle(fontSize: 13, color: AppTheme.primaryContainer, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6DDD8)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
