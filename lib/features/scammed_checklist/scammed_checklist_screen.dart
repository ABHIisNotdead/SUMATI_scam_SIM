import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/realistic_voice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/scam_shield_app_bar.dart';

class ScammedChecklistScreen extends ConsumerStatefulWidget {
  const ScammedChecklistScreen({super.key});

  @override
  ConsumerState<ScammedChecklistScreen> createState() => _ScammedChecklistScreenState();
}

class _ScammedChecklistScreenState extends ConsumerState<ScammedChecklistScreen> {
  final List<bool> _completedSteps = [false, false, false, false];

  // AI Listener State
  final TextEditingController _aiListenerController = TextEditingController();
  String? _aiTriageAdvice;
  bool _isSpeakingAdvice = false;

  // Share Scam to Sumati AI State
  final TextEditingController _scammerPhoneController = TextEditingController();
  final TextEditingController _scammerUpiController = TextEditingController();
  final TextEditingController _scammerLinkController = TextEditingController();
  final TextEditingController _scamAmountController = TextEditingController();
  final TextEditingController _scamNoteController = TextEditingController();

  bool _isSubmittingToAi = false;
  Map<String, dynamic>? _submittedReportResponse;

  @override
  void dispose() {
    _aiListenerController.dispose();
    _scammerPhoneController.dispose();
    _scammerUpiController.dispose();
    _scammerLinkController.dispose();
    _scamAmountController.dispose();
    _scamNoteController.dispose();
    ref.read(realisticVoiceProvider).stop();
    super.dispose();
  }

  void _toggleStep(int index) {
    setState(() {
      _completedSteps[index] = !_completedSteps[index];
    });
  }

  Future<void> _callHelpline() async {
    final uri = Uri.parse('tel:1930');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dialing 1930 Cyber Helpline...')),
        );
      }
    }
  }

  // ── AI Listener: Immediate Calming Triage Guidance (via Groq AI API) ──────
  Future<void> _processAiListener(String input, String lang) async {
    final text = input.toLowerCase().trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    String advice = '';
    String? audioB64;

    // 1. Call Groq AI API backend for real-time emergency triage
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/emergency_triage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': input, 'lang': lang}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        advice = data['advice'] as String? ?? '';
        audioB64 = data['audio_b64'] as String?;
      }
    } catch (_) {
      // Backend offline or timeout: use smart on-device triage
    }

    if (advice.isEmpty) {
      if (text.contains('otp') || text.contains('bank') || text.contains('account')) {
        advice = lang == 'hi'
            ? 'घबराएं नहीं, शांत रहें। सबसे पहले तुरंत 1930 पर कॉल करें। फिर अपने बैंक कस्टमर केयर को फोन करके अपना डेबिट कार्ड और नेटबैंकिंग ब्लॉक करवाएं।'
            : 'Stay calm. Golden Hour rule: Immediately call 1930 Cyber Cell to freeze the transaction. Next, call your bank customer care to block your card and netbanking.';
      } else if (text.contains('anydesk') || text.contains('teamviewer') || text.contains('app') || text.contains('download')) {
        advice = lang == 'hi'
            ? 'तुरंत अपने फोन का इंटरनेट (WiFi और Mobile Data) बंद कर दें! फोन से AnyDesk या TeamViewer ऐप को तुरंत अनइंस्टॉल करें और फोन रीस्टार्ट करें।'
            : 'Turn off your phone’s WiFi & Mobile Data immediately! Uninstall AnyDesk, TeamViewer, or any suspicious app right now, then restart your phone.';
      } else if (text.contains('police') || text.contains('arrest') || text.contains('cbi') || text.contains('parcel')) {
        advice = lang == 'hi'
            ? 'यह 100% फर्जी डिजिटल अरेस्ट फ्रॉड है। भारत में कोई भी पुलिस वीडियो कॉल पर अरेस्ट नहीं करती। तुरंत कॉल काटें और 1930 पर शिकायत दर्ज करें।'
            : 'This is 100% fake Digital Arrest fraud. Indian police NEVER conduct arrests on video calls. Do not pay any money. Disconnect and report to 1930.';
      } else {
        advice = lang == 'hi'
            ? 'हम आपके साथ हैं। सबसे पहला और महत्वपूर्ण कदम 1930 साइबर हेल्पलाइन पर कॉल करना और परिवार को सूचित करना है।'
            : 'We are here to help. Your primary emergency action is calling 1930 Cyber Helpline right away and alerting your family.';
      }
    }

    if (!mounted) return;

    setState(() {
      _aiTriageAdvice = advice;
    });

    _speakAdvice(advice, audioB64: audioB64, lang: lang);
  }

  void _speakAdvice(String text, {String? audioB64, String? lang}) async {
    setState(() => _isSpeakingAdvice = true);
    final voiceService = ref.read(realisticVoiceProvider);

    if (audioB64 != null && audioB64.isNotEmpty) {
      await voiceService.playBase64Audio(audioB64, onComplete: () {
        if (mounted) setState(() => _isSpeakingAdvice = false);
      });
    } else {
      final activeLang = lang ?? ref.read(preferencesProvider).appLanguage;
      await voiceService.speakRealistic(text, activeLang, onComplete: () {
        if (mounted) setState(() => _isSpeakingAdvice = false);
      });
    }
  }

  void _stopSpeaking() {
    ref.read(realisticVoiceProvider).stop();
    setState(() => _isSpeakingAdvice = false);
  }

  // ── Share Scam to Sumati AI (Records Data to Train New Scenarios) ──────────
  Future<void> _submitScamDetailsToSumatiAi() async {
    final note = _scamNoteController.text.trim();
    final phone = _scammerPhoneController.text.trim();
    final upi = _scammerUpiController.text.trim();
    final link = _scammerLinkController.text.trim();
    final amount = _scamAmountController.text.trim();

    if (note.isEmpty && phone.isEmpty && upi.isEmpty && link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter what happened or provide scammer details.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmittingToAi = true);

    final lang = ref.read(preferencesProvider).appLanguage;

    // 1. Save locally in Hive box
    final box = Hive.isBoxOpen('preferences') ? Hive.box('preferences') : null;
    final userPhone = (box?.get('userPhone', defaultValue: '') as String? ?? '').trim();
    if (box != null) {
      final existingList = box.get('community_scam_reports', defaultValue: <dynamic>[]) as List<dynamic>;
      final newReport = {
        'timestamp': DateTime.now().toIso8601String(),
        'user_phone': userPhone,
        'phone': phone,
        'upi': upi,
        'link': link,
        'amount': amount,
        'story': note,
        'language': lang,
      };
      final updatedList = List<dynamic>.from(existingList)..add(newReport);
      box.put('community_scam_reports', updatedList);
    }

    String tailoredAdvice = '';
    String? audioB64;
    int? reportId;

    // 2. Submit to Groq AI API backend + SQLite database to record intelligence & synthesize realistic voice
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/scam_reports'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_phone': userPhone,
          'phone': phone,
          'upi': upi,
          'link': link,
          'amount': amount,
          'story': note,
          'lang': lang,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        tailoredAdvice = data['advice'] as String? ?? '';
        audioB64 = data['audio_b64'] as String?;
        reportId = data['report_id'] as int?;
      }
    } catch (_) {
      // Backend offline: use heuristic advice
    }

    if (tailoredAdvice.isEmpty) {
      final parsedAmount = int.tryParse(amount) ?? 0;
      if (parsedAmount > 0) {
        tailoredAdvice = lang == 'hi'
            ? 'आपके ₹$amount के नुकसान के लिए सबसे जरूरी कदम: 2 घंटे के भीतर तुरंत 1930 पर कॉल करें। साइबर सेल बैंक ट्रांजेक्शन को बीच में फ्रीज कर सकती है।'
            : 'Since money (₹$amount) was debited, the 2-hour Golden Window is crucial: Dial 1930 immediately so the cyber crime unit can freeze the recipient account.';
      } else if (note.toLowerCase().contains('link') || link.isNotEmpty) {
        tailoredAdvice = lang == 'hi'
            ? 'अगर आपने लिंक खोला था, तो अपने बैंक और यूपीआई का पासवर्ड बदल लें और फोन में कोई भी नई अनजान ऐप चेक करके तुरंत डिलीट करें।'
            : 'If you clicked the malicious link, immediately change your UPI PIN & NetBanking passwords, and ensure no unknown apps were installed.';
      } else {
        tailoredAdvice = lang == 'hi'
            ? 'इस नंबर को तुरंत अपने फोन और व्हाट्सएप पर ब्लॉक करें। किसी भी अनजान नंबर पर दोबारा संपर्क न करें।'
            : 'Block this scammer on WhatsApp and your phone. Sumati AI has safely recorded these tactics to design new practice drills.';
      }
    }

    if (!mounted) return;

    setState(() {
      _isSubmittingToAi = false;
      _submittedReportResponse = {
        'advice': tailoredAdvice,
        'date': DateTime.now().toString().split('.')[0],
        'audio_b64': audioB64,
        'report_id': reportId,
      };
    });

    _speakAdvice(tailoredAdvice, audioB64: audioB64, lang: lang);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(preferencesProvider).appLanguage;

    final steps = [
      {
        'title': UiStrings.get(lang, 'step_helpline_title'),
        'subtitle': UiStrings.get(lang, 'step_helpline_sub'),
        'icon': Icons.phone_in_talk_rounded,
        'badge': '1930',
        'isPriority': true,
      },
      {
        'title': UiStrings.get(lang, 'step_bank_title'),
        'subtitle': UiStrings.get(lang, 'step_bank_sub'),
        'icon': Icons.account_balance_rounded,
        'badge': 'FREEZE',
        'isPriority': true,
      },
      {
        'title': UiStrings.get(lang, 'step_pin_title'),
        'subtitle': UiStrings.get(lang, 'step_pin_sub'),
        'icon': Icons.lock_reset_rounded,
        'badge': 'SECURITY',
        'isPriority': false,
      },
      {
        'title': UiStrings.get(lang, 'step_complaint_title'),
        'subtitle': UiStrings.get(lang, 'step_complaint_sub'),
        'icon': Icons.gavel_rounded,
        'badge': 'PORTAL',
        'isPriority': false,
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: ScamShieldAppBar(
        title: UiStrings.get(lang, 'emergency_checklist'),
      ),
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
              children: [
                // 1. High-Urgency Reassuring Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.tertiaryFixed,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.tertiary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.tertiary.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.tertiary.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emergency_rounded,
                          color: AppTheme.tertiary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        UiStrings.get(lang, 'act_fast_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.tertiary,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        UiStrings.get(lang, 'act_fast_sub'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5A1A1A),
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── 2. AI EMERGENCY LISTENER (बोलकर बताएं क्या हुआ) ───────────
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryFixed,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, color: AppTheme.primary, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang == 'hi'
                                    ? 'एआई आपातकालीन सहायक (AI Listener)'
                                    : 'AI Emergency Listener',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '24/7 TRIAGE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              lang == 'hi'
                                  ? 'क्या हुआ? यहाँ संक्षेप में लिखें या बताएं (उदा. OTP दिया, पैसा कटा, बिजली बिल)'
                                  : 'Tell Sumati AI what happened (e.g. shared OTP, money deducted, AnyDesk installed):',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _aiListenerController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: lang == 'hi' ? 'यहाँ लिखें क्या हुआ...' : 'Describe what happened...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Quick scenario chips for seniors
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildScenarioChip('Shared OTP / ओटीपी दिया', lang),
                                _buildScenarioChip('AnyDesk App installed', lang),
                                _buildScenarioChip('Digital Arrest Police Threat', lang),
                                _buildScenarioChip('Money Debited from Bank', lang),
                              ],
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () => _processAiListener(_aiListenerController.text, lang),
                                icon: const Icon(Icons.bolt_rounded, size: 20),
                                label: Text(
                                  lang == 'hi' ? 'तुरंत सहायता प्राप्त करें ▶' : 'Get Immediate AI Guidance ▶',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryContainer,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),

                            // AI Triage Advice Card (with Voice Speaker)
                            if (_aiTriageAdvice != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.support_agent_rounded, color: Color(0xFF92400E), size: 22),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'AI EMERGENCY GUIDANCE:',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                                        ),
                                        const Spacer(),
                                        InkWell(
                                          onTap: () {
                                            if (_isSpeakingAdvice) {
                                              _stopSpeaking();
                                            } else {
                                              _speakAdvice(_aiTriageAdvice!);
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isSpeakingAdvice ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                                  color: const Color(0xFF92400E),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _isSpeakingAdvice ? 'Stop' : 'Listen',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _aiTriageAdvice!,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF78350F), height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── 3. WHAT TO DO (Immediate Action Steps) ─────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      UiStrings.get(lang, 'immediate_steps'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  final isDone = _completedSteps[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.surfaceContainerLow : AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDone ? AppTheme.primaryContainer : const Color(0xFFE2E6E2),
                        width: isDone ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _toggleStep(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isDone ? AppTheme.primaryContainer : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDone ? AppTheme.primaryContainer : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isDone ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          step['title'] as String,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: isDone ? AppTheme.onSurfaceVariant : AppTheme.onSurface,
                                            decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      if (step['badge'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.tertiaryFixed,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            step['badge'] as String,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.tertiary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    step['subtitle'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDone
                                          ? AppTheme.onSurfaceVariant.withValues(alpha: 0.7)
                                          : AppTheme.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // Direct Helpline Call Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _callHelpline,
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 24),
                    label: Text(
                      UiStrings.get(lang, 'call_1930'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tertiary,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // ── 4. SHARE SCAM & SCAMMER DETAILS TO SUMATI AI ──────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD6DDD8), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryFixed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.psychology_rounded, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'hi'
                                      ? 'सुमति एआई को अपना स्कैम अनुभव बताएं'
                                      : 'Share Scam & Scammer Details With Sumati AI',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang == 'hi'
                                      ? 'सुमति एआई को बताएं कि आपके साथ क्या हुआ ताकि हम आपको मार्गदर्शन दे सकें और दूसरों के लिए नए अभ्यास बना सकें।'
                                      : 'Share how scammers tried to trick you so our AI can guide you and create new practice drills for others.',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // MANDATORY DISCLAIMER LINE (as requested by user)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED), // Warm amber notice
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang == 'hi'
                                    ? '(यह कोई पुलिस शिकायत या आधिकारिक रिपोर्ट नहीं है, हम केवल स्कैम से निपटने में मदद करते हैं और इस डेटा से नए सुरक्षा अभ्यास तैयार करते हैं)'
                                    : '(this is not a scam report/ complaint we just help how to deal with the scam and build defense simulations)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A3412),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Input 1: Scammer Phone / WhatsApp
                      TextField(
                        controller: _scammerPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Scammer Phone / WhatsApp (जालसाज का नंबर)',
                          hintText: '+91 98XXX XXXXX',
                          prefixIcon: const Icon(Icons.phone_disabled_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Input 2: Scammer UPI ID / Account
                      TextField(
                        controller: _scammerUpiController,
                        decoration: InputDecoration(
                          labelText: 'Scammer UPI ID / Bank (यूपीआई या खाता)',
                          hintText: 'fraud@okaxis or Account Number',
                          prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Input 3: Amount Lost (₹)
                      TextField(
                        controller: _scamAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount Transferred / नुकसान राशि (₹)',
                          hintText: 'e.g. 5000 (Enter 0 if avoided)',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Input 4: Fraud Link or Website
                      TextField(
                        controller: _scammerLinkController,
                        decoration: InputDecoration(
                          labelText: 'Fake Link / App Name (वेबसाइट लिंक या ऐप)',
                          hintText: 'e.g. http://bit.ly/... or AnyDesk',
                          prefixIcon: const Icon(Icons.link_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Input 5: Description
                      TextField(
                        controller: _scamNoteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'What did the scammer say & what happened? (विवरण)',
                          hintText: 'e.g. Called claiming electricity bill unpaid, threatened power cut, asked to install app...',
                          prefixIcon: const Icon(Icons.description_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit Button to Sumati AI
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmittingToAi ? null : _submitScamDetailsToSumatiAi,
                          icon: _isSubmittingToAi
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_rounded, size: 22),
                          label: Text(
                            lang == 'hi'
                                ? 'सुमति एआई को भेजें • रिकॉर्ड व मार्गदर्शन पाएं ▶'
                                : 'Submit to Sumati AI • Get Guidance & Help Train AI ▶',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryContainer,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),

                      // Response confirmation from Sumati AI
                      if (_submittedReportResponse != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      lang == 'hi'
                                          ? 'सुमति एआई द्वारा सुरक्षित रिकॉर्ड किया गया!'
                                          : 'Recorded by Sumati AI Intelligence!',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lang == 'hi'
                                    ? 'धन्यवाद! आपके अनुभव से सुमति एआई नए सुरक्षा अभ्यास तैयार करेगा ताकि अन्य वरिष्ठ नागरिक इस फ्रॉड से बच सकें।'
                                    : 'Thank you for sharing! Sumati AI has recorded these tactics to design new simulation scenarios so other users can train against this scam.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF065F46), height: 1.35),
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFFA7F3D0)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'SUMATI AI IMMEDIATE GUIDANCE:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      if (_isSpeakingAdvice) {
                                        _stopSpeaking();
                                      } else {
                                        _speakAdvice(
                                          _submittedReportResponse!['advice'] as String,
                                          audioB64: _submittedReportResponse!['audio_b64'] as String?,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF10B981)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isSpeakingAdvice ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                            size: 16,
                                            color: const Color(0xFF047857),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isSpeakingAdvice ? 'Stop' : 'Listen',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _submittedReportResponse!['advice'] as String,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), height: 1.35),
                              ),
                              if (_submittedReportResponse!['report_id'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    'Database Ref: Report #${_submittedReportResponse!['report_id']}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // View Community Reports Button
                      OutlinedButton.icon(
                        onPressed: () => context.push('/scam_reports_feed'),
                        icon: const Icon(Icons.dataset_rounded, size: 20),
                        label: Text(
                          lang == 'hi'
                              ? '📋 सभी समुदाय स्कैम रिपोर्ट देखें (डेटाबेस फीड)'
                              : '📋 View All Scam Reports (Database Feed)',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Return to Home
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.go('/'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      UiStrings.get(lang, 'return_home'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioChip(String label, String lang) {
    return InkWell(
      onTap: () {
        _aiListenerController.text = label;
        _processAiListener(label, lang);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6DDD8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
