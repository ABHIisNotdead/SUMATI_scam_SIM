import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/localization/ui_strings.dart';
import '../../core/providers/os_notification_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/realistic_voice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/large_button.dart';
import '../../core/widgets/practice_tag.dart';
import '../../core/widgets/scam_shield_app_bar.dart';
import '../call_practice/providers/call_audio_provider.dart';
import '../message_practice/providers/message_session_provider.dart';

/// Post-Scam Analytics Report & Debrief Screen.
/// Clearly breaks down:
/// 1. The Hook: Psychological levers used to manipulate the user.
/// 2. The Leak: Specific data points compromised (OTP, credentials, APK).
/// 3. The Giveaway: Obvious red flags that exposed the fraud.
/// Synthesizes neural voice automatically on load so elderly users don't have to read long text.
/// Resets all OS notification badges and halts active drill WebSockets upon entry.
class DebriefScreen extends ConsumerStatefulWidget {
  final String outcome;
  final String? customMessage;
  final String? scenarioId;
  final String? hook;
  final String? leak;
  final String? giveaway;

  const DebriefScreen({
    super.key,
    required this.outcome,
    this.customMessage,
    this.scenarioId,
    this.hook,
    this.leak,
    this.giveaway,
  });

  @override
  ConsumerState<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends ConsumerState<DebriefScreen> {
  bool _isPlayingVoice = false;
  String _audioScript = '';
  String? _tacticsExplanation;
  List<String> _dos = [];
  List<String> _donts = [];
  RealisticVoiceService? _voiceService;

  late String _activeHook;
  late String _activeLeak;
  late String _activeGiveaway;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(realisticVoiceProvider);

    _resolveAnalyticsContent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Constraint: Reset all OS notification badges and halt active sessions upon entry
      _resetOsAndActiveSessions();
      if (mounted) {
        _fetchDebriefAndSpeak();
      }
    });
  }

  void _resetOsAndActiveSessions() {
    // 1. Reset all OS badges, banners, and compromise alerts
    ref.read(osNotificationProvider.notifier).resetAll();

    // 2. Halt active call engine & WebSocket
    ref.read(callAudioProvider.notifier).endCall();

    // 3. Clear active message thread
    ref.read(messageSessionProvider.notifier).selectThread(null);
  }

  void _resolveAnalyticsContent() {
    final isSuccess = widget.outcome.startsWith('success');

    // 1. The Hook (Psychological trigger)
    _activeHook = widget.hook ??
        (isSuccess
            ? 'The scammer attempted to weaponize Artificial Urgency and False Legal Authority to induce immediate panic before you could verify facts.'
            : 'The scammer successfully triggered Urgency & Fear of Penalty, making you feel your funds or electricity would be terminated unless you complied immediately.');

    // 2. The Leak (Sensitive data points compromised)
    _activeLeak = widget.leak ??
        (isSuccess
            ? 'None! You kept your confidential banking OTPs, PINs, and personal identity documents completely safe.'
            : 'Confidential Information Shared: OTP / Account Credentials / Authorization granted to unverified third-party.');

    // 3. The Giveaway (Red flags missed)
    _activeGiveaway = widget.giveaway ??
        'Red Flags: Demanding confidential OTPs over phone/links, unverified HTTP connection ("Not Secure" warning), and claiming "Digital Arrest" which does not exist in Indian law.';
  }

  @override
  void dispose() {
    _voiceService?.stop();
    super.dispose();
  }

  Future<void> _fetchDebriefAndSpeak() async {
    final lang = ref.read(preferencesProvider).appLanguage;
    final isSuccess = widget.outcome.startsWith('success');

    // Default rich fallback text (ensures zero-latency playback even if backend network is cold)
    _dos = [
      lang == 'hi'
          ? 'कॉल तुरंत काटें और स्थानीय बैंक शाखा या थाने जाकर स्वतंत्र रूप से जांच करें।'
          : (lang == 'mr'
              ? 'कॉल त्वरित कट करा आणि बँक किंवा पोलिस ठाण्यात जाऊन खात्री करा.'
              : 'Immediately hang up and verify independently at your local bank branch or police station.'),
      lang == 'hi'
          ? 'साइबर हेल्पलाइन नंबर 1930 पर कॉल करें या cybercrime.gov.in पर रिपोर्ट दर्ज करें।'
          : (lang == 'mr'
              ? 'सायबर हेल्पलाइन क्रमांक 1930 वर संपर्क करा किंवा तक्रार नोंदवा.'
              : 'Call the National Cyber Crime Helpline 1930 or report on cybercrime.gov.in.'),
      lang == 'hi'
          ? 'किसी भी वित्तीय निर्णय से पहले परिवार के सदस्यों से खुलकर बात करें।'
          : (lang == 'mr'
              ? 'कोणत्याही पैशांच्या व्यवहाराआधी कुटुंबाशी चर्चा करा.'
              : 'Always consult a trusted family member or friend before taking financial action.'),
    ];

    _donts = [
      lang == 'hi'
          ? 'फोन या वीडियो कॉल पर कभी भी ओटीपी, पिन, पासवर्ड या बैंक विवरण साझा न करें।'
          : (lang == 'mr'
              ? 'फोनवर कधीही ओटीपी, पासवर्ड किंवा बँक तपशील देऊ नका.'
              : 'Never share OTP, PIN, password, or banking credentials over phone or video call.'),
      lang == 'hi'
          ? 'किसी भी \'सरकारी सुरक्षा खाते\' या अज्ञात यूपीआई आईडी पर पैसे ट्रांसफर न करें।'
          : (lang == 'mr'
              ? 'कोणत्याही \'सुरक्षित खात्यावर\' किंवा अनोळखी खात्यावर पैसे पाठवू नका.'
              : 'Never transfer funds to "verification accounts" or unknown UPI IDs.'),
      lang == 'hi'
          ? 'एसएमएस में आए अज्ञात लिंक पर क्लिक न करें और न ही कोई रिमोट ऐप इंस्टॉल करें।'
          : (lang == 'mr'
              ? 'अनोळखी लिंकवर क्लिक करू नका आणि कोणतेही ॲप इन्स्टॉल करू नका.'
              : 'Never click links in SMS or install remote control apps (AnyDesk, TeamViewer).'),
    ];

    final defaultTactics = isSuccess
        ? (lang == 'hi'
            ? 'शानदार बचाव! असली ठग फर्जी वर्दी, नकली सुप्रीम कोर्ट के आदेश और डिजिटल अरेस्ट की झूठी धमकियां देकर घबराहट पैदा करते हैं। याद रखें: भारतीय कानून में \'डिजिटल अरेस्ट\' नाम की कोई चीज नहीं है।'
            : (lang == 'mr'
                ? 'छान बचाव! खरे भामटे खोट्या पोलिस वर्दीचा आणि अटकेचा धाक दाखवून फसवतात. लक्षात ठेवा: भारतीय कायद्यात डिजिटल अरेस्ट अस्तित्वात नाही.'
                : 'Outstanding defense! Real scammers exploit false authority, fake police badges, and forged court warrants to induce immediate panic. Remember: Indian law has NO concept of "Digital Arrest". Real police never interrogate or demand payments over phone.'))
        : (lang == 'hi'
            ? 'सावधान! असली ठग पीड़ितों को डराने के लिए कानूनी धाराओं और तुरंत खाते फ्रीज करने का झूठा डर दिखाते हैं। वे जल्दबाजी में फैसले लेने पर मजबूर करते हैं ताकि सोचने का मौका न मिले।'
            : (lang == 'mr'
                ? 'सावध राहा! भामटे भीती आणि घाईचा गैरफायदा घेऊन बँक खात्याचे नुकसान करतात.'
                : 'In real scams, fraudsters use psychological pressure, urgency traps, and fabricated legal authority to prevent victims from thinking calmly. Never rush into compliance.'));

    _tacticsExplanation = defaultTactics;

    final dosSpoken = _dos.join('. ');
    final dontsSpoken = _donts.join('. ');

    final assessmentPart = (widget.customMessage != null && widget.customMessage!.isNotEmpty)
        ? widget.customMessage!
        : (isSuccess
            ? (lang == 'hi'
                ? 'बहुत बढ़िया! आपने समझदारी से स्कैम को विफल कर दिया।'
                : (lang == 'mr'
                    ? 'खूप छान! तुम्ही हुशारीने फसवणूक टाळली.'
                    : 'Well done! You successfully defused the scam.'))
            : (lang == 'hi'
                ? 'सावधान! ऐसे निर्देशों का पालन करने से आपके पैसे का नुकसान हो सकता था।'
                : (lang == 'mr'
                    ? 'सावध राहा! अशा सूचनांचे पालन केल्यास तुमचे नुकसान झाले असते.'
                    : 'Be careful! Following these instructions could have put your accounts at risk.')));

    final whatToDoIntro = lang == 'hi'
        ? 'यहाँ बताया गया है कि आपको क्या करना चाहिए:'
        : (lang == 'mr' ? 'नेहमी हे उपाय करा:' : 'Here is what you should always do:');

    final whatToAvoidIntro = lang == 'hi'
        ? 'और इन गलतियों से हमेशा बचें:'
        : (lang == 'mr' ? 'या गोष्टी कटाक्षाने टाळा:' : 'Here is what you must always avoid:');

    _audioScript = '$assessmentPart The hook used was: $_activeHook. The leak assessment: $_activeLeak. Key red flags: $_activeGiveaway. $whatToDoIntro $dosSpoken. $whatToAvoidIntro $dontsSpoken.';

    if (mounted) {
      setState(() {});
    }

    // Attempt to enrich with backend /api/debrief
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/debrief'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'scenario_id': widget.scenarioId ?? 'call_digital_arrest',
          'outcome': widget.outcome,
          'language': lang,
          'transcript': [],
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (data['tactics_explanation'] != null) {
              _tacticsExplanation = data['tactics_explanation'].toString();
            }
            if (data['dos'] is List) {
              _dos = (data['dos'] as List).map((e) => e.toString()).toList();
            }
            if (data['donts'] is List) {
              _donts = (data['donts'] as List).map((e) => e.toString()).toList();
            }
            if (data['audio_script'] != null) {
              _audioScript = data['audio_script'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[Debrief] API fetch error (using fallback): $e');
    }

    // Automatically speak guidance via realistic neural voice
    if (mounted) {
      _playVoice();
    }
  }

  void _playVoice() async {
    if (!mounted || _audioScript.isEmpty) return;
    final lang = ref.read(preferencesProvider).appLanguage;
    setState(() => _isPlayingVoice = true);

    await _voiceService?.speakRealistic(
      _audioScript,
      lang,
      onComplete: () {
        if (mounted) setState(() => _isPlayingVoice = false);
      },
    );
  }

  void _stopVoice() async {
    await _voiceService?.stop();
    if (mounted) setState(() => _isPlayingVoice = false);
  }

  void _togglePlayPause() {
    if (_isPlayingVoice) {
      _stopVoice();
    } else {
      _playVoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = widget.outcome.startsWith('success');
    final lang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      appBar: ScamShieldAppBar(title: UiStrings.get(lang, 'practice_debrief')),
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Celebratory Cheering or Caution Header Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 80,
                        color: isSuccess ? AppTheme.green : AppTheme.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Main Title (Well Done! / Be Careful!)
                  Text(
                    isSuccess
                        ? UiStrings.get(lang, 'well_done_safe')
                        : UiStrings.get(lang, 'be_careful_trap'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? AppTheme.green : AppTheme.red,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Cheering celebration badge on success
                  if (isSuccess) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.celebration_rounded, color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            lang == 'hi'
                                ? '🎉 शाबाश! आपने समझदारी से ठग को रोक दिया!'
                                : (lang == 'mr'
                                    ? '🎉 अभिनंदन! तुम्ही यशस्वीपणे बचाव केला!'
                                    : '🎉 Well done! You successfully defused the scam!'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 3. Spoken Neural Voice Audio Player Controls Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryFixedDim.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryContainer.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlayingVoice ? Icons.volume_up_rounded : Icons.record_voice_over_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isPlayingVoice
                                ? (lang == 'hi' ? 'सुमति एआई बोल रहा है...' : 'Sumati AI Speaking...')
                                : (lang == 'hi' ? 'बोलकर सुरक्षा सलाह' : 'Audio Debrief Guidance'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton.filled(
                          icon: Icon(_isPlayingVoice ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primaryContainer,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                          tooltip: _isPlayingVoice ? 'Pause' : 'Play',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.replay_rounded, color: AppTheme.primaryContainer),
                          onPressed: _playVoice,
                          tooltip: 'Replay Voice',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Custom Message / Localized Fallback Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      widget.customMessage ?? (isSuccess
                          ? (lang == 'hi'
                              ? 'बहुत बढ़िया! आपने चेतावनी के संकेतों को पहचान लिया। असली बैंक और अधिकारी कभी भी धमकी नहीं देते।'
                              : lang == 'mr'
                                  ? 'छान! तुम्ही धोक्याचे इशारे ओळखले. खरी बँक आणि अधिकारी कधीही धमकी देत नाहीत.'
                                  : 'Great job recognizing the warning signs. Real banks and authorities will never threaten you or ask for sensitive details over an unverified call.')
                          : (lang == 'hi'
                              ? 'सावधान! ऐसे निर्देशों का पालन करने से आपके पैसे का नुकसान हो सकता था। हमेशा कॉल काटें और स्वतंत्र रूप से सत्यापन करें।'
                              : lang == 'mr'
                                  ? 'सावध राहा! अशा सूचनांचे पालन केल्यास तुमचे नुकसान झाले असते. नेहमी कॉल कट करा आणि खात्री करा.'
                                  : 'In a real situation, following these instructions could have put your accounts or money at risk. Remember: hang up and verify independently.')),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // POST-SCAM ANALYTICS REPORT DASHBOARD
                  // (The Hook, The Leak, The Giveaway)
                  // ==========================================
                  Text(
                    '🔍 Post-Scam Analytics Report',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Card 1: The Hook
                  _buildAnalyticsCard(
                    title: 'The Hook (मनोवैज्ञानिक चाल)',
                    description: _activeHook,
                    icon: Icons.psychology_rounded,
                    accentColor: const Color(0xFFF59E0B), // Amber
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                  ),

                  const SizedBox(height: 12),

                  // Card 2: The Leak
                  _buildAnalyticsCard(
                    title: isSuccess ? 'The Leak (कोई जानकारी लीक नहीं)' : 'The Leak (लीक हुई संवेदनशील जानकारी)',
                    description: _activeLeak,
                    icon: isSuccess ? Icons.security_rounded : Icons.leak_add_rounded,
                    accentColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFDC2626), // Green vs Red
                    bgColor: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderColor: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),

                  const SizedBox(height: 12),

                  // Card 3: The Giveaway
                  _buildAnalyticsCard(
                    title: 'The Giveaway (पहचान के मुख्य संकेत)',
                    description: _activeGiveaway,
                    icon: Icons.lightbulb_outline_rounded,
                    accentColor: const Color(0xFF0284C7), // Sky Blue
                    bgColor: const Color(0xFFF0F9FF),
                    borderColor: const Color(0xFFBAE6FD),
                  ),

                  const SizedBox(height: 24),

                  // 5. How Real Scammers Trick You (Psychological Manipulation Tactics)
                  if (_tacticsExplanation != null && _tacticsExplanation!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology_rounded, color: Color(0xFFF57F17), size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lang == 'hi'
                                      ? '🧠 असली ठग आपको कैसे फंसाते हैं:'
                                      : (lang == 'mr'
                                          ? '🧠 खरे भामटे फसवणूक कशी करतात:'
                                          : '🧠 How Real Scammers Trick You:'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFF57F17)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _tacticsExplanation!,
                            style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 6. What to Do & What NOT to Do Breakdown
                  Text(
                    lang == 'hi' ? '🛡️ क्या करें और क्या न करें:' : '🛡️ What to Do & What NOT to Do:',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Do's List
                  ..._dos.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)))),
                          ],
                        ),
                      )),

                  const SizedBox(height: 8),

                  // Don'ts List
                  ..._donts.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_rounded, color: Color(0xFFC62828), size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFB71C1C)))),
                          ],
                        ),
                      )),

                  const SizedBox(height: 28),

                  // 7. Key Takeaways Section (Required by widget tests)
                  Text(
                    UiStrings.get(lang, 'key_takeaways'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTakeawayRow(UiStrings.get(lang, 'takeaway_1')),
                  _buildTakeawayRow(UiStrings.get(lang, 'takeaway_2')),
                  _buildTakeawayRow(UiStrings.get(lang, 'takeaway_3')),

                  const SizedBox(height: 36),

                  // 8. Navigation Buttons
                  LargeButton(
                    text: UiStrings.get(lang, 'practice_again'),
                    onPressed: () => context.go('/practice/call'),
                  ),
                  const SizedBox(height: 14),
                  LargeButton(
                    text: UiStrings.get(lang, 'choose_another_scam'),
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.primaryTeal,
                    onPressed: () => context.go('/scam_picker'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeawayRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: AppTheme.primaryTeal, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18))),
        ],
      ),
    );
  }
}
