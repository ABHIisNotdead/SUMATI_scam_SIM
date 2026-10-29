import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/providers/scenario_provider.dart';
import '../../core/models/scenario.dart';
import '../../core/models/simulation_result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/services/user_sync_service.dart';

class ScamPickerScreen extends ConsumerStatefulWidget {
  const ScamPickerScreen({super.key});

  @override
  ConsumerState<ScamPickerScreen> createState() => _ScamPickerScreenState();
}

class _ScamPickerScreenState extends ConsumerState<ScamPickerScreen> {
  void _navigateToScenario(BuildContext context, Scenario scenario) {
    String title = scenario.title;
    String persona = scenario.persona ?? "a scammer trying to trick the user";
    String initialMsg = scenario.initialMessage ?? "Hello. Please respond urgently.";

    if (scenario.channel == 'call') {
      title = "Incoming Call: ${scenario.scammerName ?? scenario.title}";
    } else if (scenario.channel == 'whatsapp') {
      title = "WhatsApp: ${scenario.scammerName ?? scenario.title}";
    } else if (scenario.channel == 'sms') {
      title = "SMS: ${scenario.scammerName ?? scenario.title}";
    } else if (scenario.channel == 'web') {
      title = "Browser Warning: ${scenario.title}";
    }

    context.push('/fake_android', extra: {
      'scenario': scenario,
      'title': title,
      'persona': persona,
      'initialMsg': initialMsg,
      'channel': scenario.channel,
    });
  }

  void _startRandomUnpracticedScenario(List<Scenario> scenarios, BuildContext context) {
    if (scenarios.isEmpty) return;

    final box = Hive.isBoxOpen('simulation_results') ? Hive.box('simulation_results') : null;
    final completedTitles = <String>{};

    if (box != null) {
      for (int i = 0; i < box.length; i++) {
        final item = box.getAt(i);
        if (item is SimulationResult) {
          completedTitles.add(item.scenarioTitle.toLowerCase());
        }
      }
    }

    // Filter for scenarios not yet completed
    final unpracticed = scenarios.where((s) {
      final title = s.title.toLowerCase();
      return !completedTitles.any((done) => done.contains(title) || title.contains(done));
    }).toList();

    final random = Random();
    final chosen = unpracticed.isNotEmpty
        ? unpracticed[random.nextInt(unpracticed.length)]
        : scenarios[random.nextInt(scenarios.length)];

    _navigateToScenario(context, chosen);
  }

  void _startModalityPractice(String channel, BuildContext context) {
    context.push('/scenarios', extra: channel);
  }

  void _showSignInModal(BuildContext context) {
    final prefBox = Hive.box('preferences');
    final currentName = prefBox.get('userName', defaultValue: 'दादा जी (Senior)') as String;
    final currentPhone = prefBox.get('userPhone', defaultValue: '') as String;
    final currentPin = UserSyncService.getOrCreatePin();

    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Profile / उपयोगकर्ता प्रोफ़ाइल',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Your Name / नाम (e.g. दादा जी)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.badge_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number / मोबाइल नंबर',
                hintText: '98201 XXXXX',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 14),
            // Family PIN display card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF15803D), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Family Connect 4-Digit PIN:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                        Text(
                          currentPin,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF15803D), letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: currentPin));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newPhone = phoneController.text.trim();
                  prefBox.put('userName', newName);
                  prefBox.put('userPhone', newPhone);
                  
                  // Sync with backend SQLite
                  await UserSyncService.syncUserProfile(
                    name: newName,
                    phone: newPhone,
                    pin: currentPin,
                  );

                  if (mounted) {
                    setState(() {});
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile & PIN synced with database! • प्रोफ़ाइल सहेजी गई')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Profile / सहेजें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFamilyConnectModal(BuildContext context) {
    final prefBox = Hive.box('preferences');
    final currentPhone = prefBox.get('userPhone', defaultValue: '') as String;
    final currentName = prefBox.get('userName', defaultValue: 'दादा जी (Senior)') as String;
    final currentPin = UserSyncService.getOrCreatePin();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.family_restroom_rounded, color: Color(0xFF2E7D32), size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Family Connect • परिवार सुरक्षा लिंक',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Share your registered Mobile Number and 4-digit Security PIN with your children or guardian so they can securely monitor your safety scores and alerts.',
              style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 18),
            // Phone and PIN details card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Senior Mobile Number:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      Text(
                        currentPhone.isNotEmpty ? currentPhone : '(Tap Profile to set)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: currentPhone.isNotEmpty ? AppTheme.primary : Colors.orange[800]),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Security PIN / पिन:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      Text(
                        currentPin,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: 2.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Share via WhatsApp / Copy Action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final shareMsg = 'Sumati Family Connect:\nSenior: $currentName\nMobile: $currentPhone\nSecurity PIN: $currentPin\nEnter these on Family Dashboard to view my live safety status.';
                      Clipboard.setData(ClipboardData(text: shareMsg));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connection details copied! Share with your family.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Details'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/family_dashboard');
                    },
                    icon: const Icon(Icons.dashboard_rounded, size: 18),
                    label: const Text('Open Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenariosAsync = ref.watch(scenarioListProvider);
    final currentLang = ref.watch(preferencesProvider).appLanguage;
    final userName = Hive.isBoxOpen('preferences')
        ? Hive.box('preferences').get('userName', defaultValue: 'दादा जी (Senior)') as String
        : 'दादा जी (Senior)';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        toolbarHeight: 66,
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sumati सुरक्षा',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  UiStrings.get(currentLang, 'suraksha_subtitle'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Profile / Sign In Pill
          InkWell(
            onTap: () => _showSignInModal(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD6DDD8), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Family Connect Button
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => _showFamilyConnectModal(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF81C784), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.family_restroom_rounded, color: Color(0xFF2E7D32), size: 18),
                    SizedBox(width: 4),
                    Text(
                      'परिवार',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Safety Ribbon
          const PracticeTag(),

          Expanded(
            child: scenariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (scenarios) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    // 1. Language Toggle Bar
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _buildLangPill('en', 'English', currentLang),
                          _buildLangPill('hi', 'हिंदी', currentLang),
                          _buildLangPill('mr', 'मराठी', currentLang),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Simple Senior Safety Score Card
                    _buildSimpleScoreCard(context),

                    const SizedBox(height: 16),

                    // 3. HERO CTA: ⚡ Practice Now (Starts a random unpracticed drill)
                    _buildPracticeNowHero(scenarios, context, currentLang),

                    const SizedBox(height: 18),

                    // 4. Section Title: Choose Modality
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentLang == 'hi'
                              ? 'सराव के प्रकार • PRACTICE MODES'
                              : currentLang == 'mr'
                                  ? 'सरावाचे प्रकार • PRACTICE MODES'
                                  : 'PRACTICE MODES',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurfaceVariant,
                            letterSpacing: 0.6,
                          ),
                        ),
                        InkWell(
                          onTap: () => context.push('/scenarios'),
                          child: Text(
                            currentLang == 'hi'
                                ? 'सारे अभ्यास (${scenarios.length}) ▶'
                                : 'All Scenarios (${scenarios.length}) ▶',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 5. 4 Clear Practice Modalities (2x2 Clean Grid)
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalityTile(
                            icon: Icons.phone_in_talk_rounded,
                            iconColor: Colors.white,
                            bgColor: const Color(0xFF00875A),
                            title: UiStrings.get(currentLang, 'call_practice'),
                            subtitle: currentLang == 'hi'
                                ? '${scenarios.where((s) => s.channel == 'call').length} कॉल अभ्यास'
                                : '${scenarios.where((s) => s.channel == 'call').length} Call Scenarios',
                            onTap: () => _startModalityPractice('call', context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModalityTile(
                            icon: Icons.chat_rounded,
                            iconColor: Colors.white,
                            bgColor: const Color(0xFF008069),
                            title: 'WhatsApp',
                            subtitle: currentLang == 'hi'
                                ? '${scenarios.where((s) => s.channel == 'whatsapp').length} व्हाट्सएप अभ्यास'
                                : '${scenarios.where((s) => s.channel == 'whatsapp').length} WhatsApp Scenarios',
                            onTap: () => _startModalityPractice('whatsapp', context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalityTile(
                            icon: Icons.textsms_rounded,
                            iconColor: Colors.white,
                            bgColor: const Color(0xFF0B57D0),
                            title: 'SMS Message',
                            subtitle: currentLang == 'hi'
                                ? '${scenarios.where((s) => s.channel == 'sms').length} एसएमएस अभ्यास'
                                : '${scenarios.where((s) => s.channel == 'sms').length} SMS Scenarios',
                            onTap: () => _startModalityPractice('sms', context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModalityTile(
                            icon: Icons.public_rounded,
                            iconColor: Colors.white,
                            bgColor: const Color(0xFFC62828),
                            title: UiStrings.get(currentLang, 'website_practice'),
                            subtitle: currentLang == 'hi'
                                ? '${scenarios.where((s) => s.channel == 'web').length} वेबसाइट अभ्यास'
                                : '${scenarios.where((s) => s.channel == 'web').length} Web Scenarios',
                            onTap: () => _startModalityPractice('web', context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 6. View All Scenarios Banner Card
                    InkWell(
                      onTap: () => context.push('/scenarios'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD6DDD8)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryFixed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.library_books_rounded, color: AppTheme.secondary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentLang == 'hi'
                                        ? 'सारे अभ्यास देखें (${scenarios.length} Scenarios)'
                                        : currentLang == 'mr'
                                            ? 'सर्व सराव पहा (${scenarios.length} Scenarios)'
                                            : 'Browse All ${scenarios.length} Scenarios',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentLang == 'hi'
                                        ? 'अपनी पसंद का कोई भी फ्रॉड चुनकर अभ्यास करें'
                                        : 'Choose specific scams by topic or difficulty',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.outline),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 7. Onboarding Tour Replay Tile
                    InkWell(
                      onTap: () => context.push('/onboarding'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E6E2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.help_center_outlined, color: AppTheme.primary, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentLang == 'hi'
                                    ? 'ऐप का परिचय फिर से देखें (App Tour)'
                                    : 'Replay Welcome Tour & Onboarding',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.outline),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // Simplified Sticky Bottom Action Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              // Ask AI Button
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/ask_ai'),
                    icon: const Icon(Icons.smart_toy_rounded, size: 20),
                    label: Text(
                      UiStrings.get(currentLang, 'ask_ai'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF451A03),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Emergency 1930 Button
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/i_was_scammed'),
                    icon: const Icon(Icons.emergency_rounded, size: 20),
                    label: const Text(
                      '1930 Helpline',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tertiary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeNowHero(List<Scenario> scenarios, BuildContext context, String currentLang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryContainer.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '⚡ NEW PRACTICE • नया अभ्यास',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSecondaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currentLang == 'hi'
                ? 'अभी अभ्यास करें (Practice Now)'
                : currentLang == 'mr'
                    ? 'आत्ता सराव करा (Practice Now)'
                    : 'Practice Now (Recommended)',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentLang == 'hi'
                ? 'एक नया फ्रॉड कॉल या मैसेज जिसका आपने अभी तक अभ्यास नहीं किया'
                : 'Launches a random unpracticed scam simulation to test your reflexes.',
            style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _startRandomUnpracticedScenario(scenarios, context),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
              label: Text(
                currentLang == 'hi' ? 'ड्रिल शुरू करें ▶' : 'Start Random Drill ▶',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangPill(String code, String label, String currentLang) {
    final isSelected = currentLang == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(preferencesProvider.notifier).setLanguage(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleScoreCard(BuildContext context) {
    final box = Hive.isBoxOpen('simulation_results') ? Hive.box('simulation_results') : null;
    int total = box?.length ?? 0;
    int avoided = 0;
    if (box != null) {
      for (int i = 0; i < box.length; i++) {
        final item = box.getAt(i);
        if (item is SimulationResult && item.isAvoided) avoided++;
      }
    }
    final scoreRate = total > 0 ? ((avoided / total) * 100).round() : 100;

    return InkWell(
      onTap: () => context.push('/family_dashboard'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6DDD8), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Senior Safety Score: $scoreRate%',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      const Text('🎖️', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total > 0
                        ? '$total में से $avoided जालसाज पकड़े! (Tap for family view)'
                        : '100% सुरक्षित अभ्यास • Tap to see dashboard',
                    style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildModalityTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
