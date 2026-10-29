import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/widgets/large_button.dart';
import '../../core/theme/app_theme.dart';

class SeniorOnboardingScreen extends ConsumerStatefulWidget {
  const SeniorOnboardingScreen({super.key});

  @override
  ConsumerState<SeniorOnboardingScreen> createState() => _SeniorOnboardingScreenState();
}

class _SeniorOnboardingScreenState extends ConsumerState<SeniorOnboardingScreen> {
  final PageController _pageController = PageController();

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _finishOnboarding() {
    if (Hive.isBoxOpen('userSettingsBox')) {
      Hive.box('userSettingsBox').put('onboardingComplete', true);
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildLanguagePage(),
            _buildTextSizePage(),
            _buildPledgePage(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Choose your language', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          LargeButton(text: 'English', onPressed: () { ref.read(localeProvider.notifier).updateLocale('en'); _nextPage(); }),
          const SizedBox(height: 16),
          LargeButton(text: 'हिंदी', onPressed: () { ref.read(localeProvider.notifier).updateLocale('hi'); _nextPage(); }),
          const SizedBox(height: 16),
          LargeButton(text: 'मराठी', onPressed: () { ref.read(localeProvider.notifier).updateLocale('mr'); _nextPage(); }),
        ],
      ),
    );
  }

  Widget _buildTextSizePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Choose text size', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          LargeButton(text: 'Normal', onPressed: () { ref.read(textScaleProvider.notifier).updateScale(18.0); _nextPage(); }),
          const SizedBox(height: 16),
          LargeButton(text: 'Large', onPressed: () { ref.read(textScaleProvider.notifier).updateScale(22.0); _nextPage(); }),
          const SizedBox(height: 16),
          LargeButton(text: 'Extra Large', onPressed: () { ref.read(textScaleProvider.notifier).updateScale(26.0); _nextPage(); }),
        ],
      ),
    );
  }

  Widget _buildPledgePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.shield, size: 80, color: AppTheme.green),
          const SizedBox(height: 24),
          const Text('Safe Practice Space', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Stop. Don\'t share. Hang up. Check.', style: TextStyle(fontSize: 22, color: AppTheme.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('This app is for practice. No real information is shared.', style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          LargeButton(text: 'I understand', onPressed: _finishOnboarding),
        ],
      ),
    );
  }
}
