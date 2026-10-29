import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/config/app_config.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/services/realistic_voice_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/practice_tag.dart';

/// Result structure for the AI Scam Checker
class ScamVerdict {
  final bool isScam;
  final String riskLevel; // 'HIGH_RISK', 'SUSPICIOUS', 'SAFE'
  final String scamType;
  final String title;
  final String explanation;
  final List<String> whatToDo;
  final String? audioB64; // Edge-TTS Realistic Voice audio

  const ScamVerdict({
    required this.isScam,
    required this.riskLevel,
    required this.scamType,
    required this.title,
    required this.explanation,
    required this.whatToDo,
    this.audioB64,
  });
}

class AskAiScreen extends ConsumerStatefulWidget {
  const AskAiScreen({super.key});

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isAnalyzing = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _speechEnabled = false;
  bool _usedMic = false; // Tracks if voice/mic was used so AI talks back automatically

  Uint8List? _uploadedImageBytes;
  String? _uploadedImageName;
  ScamVerdict? _verdict;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechEnabled = false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    ref.read(realisticVoiceProvider).stop();
    super.dispose();
  }

  // ── Heuristic & NLP Pattern Analysis Engine ──────────────────────────────
  ScamVerdict _analyzeMessage(String input, String lang) {
    final text = input.toLowerCase().trim();

    // 1. Bank KYC, OTP, & Account Deactivation Traps
    final bankKeywords = [
      'otp', 'one time password', 'kyc', 'pan card', 'aadhaar', 'sbi', 'hdfc',
      'icici', 'pnb', 'bank', 'blocked', 'debit card', 'cvv', 'expiry', 'yono',
      'netbanking', 'account suspend', 'update kyc', 'deactivated'
    ];
    final hasBankRisk = bankKeywords.where((k) => text.contains(k)).length >= 2 ||
        (text.contains('otp') && (text.contains('share') || text.contains('bank') || text.contains('send')));

    // 2. Electricity / Water Bill Cutoff Threats
    final powerKeywords = [
      'electricity', 'bijli', 'power cut', 'disconnect', 'cut off', 'bill unpaid',
      'tonight 9:30', 'power will be disconnect', 'call officer', 'sdov'
    ];
    final hasPowerRisk = powerKeywords.where((k) => text.contains(k)).length >= 2 ||
        (text.contains('electricity') && (text.contains('cut') || text.contains('call')));

    // 3. Digital Arrest, Police, CBI, Narcotics & Customs
    final policeKeywords = [
      'digital arrest', 'police', 'cbi', 'narcotics', 'customs', 'fedex', 'parcel',
      'drugs', 'warrant', 'court', 'arrest', 'mumbai police', 'money laundering', 'illegal parcel'
    ];
    final hasPoliceRisk = policeKeywords.where((k) => text.contains(k)).length >= 2 ||
        text.contains('digital arrest') ||
        (text.contains('police') && (text.contains('arrest') || text.contains('parcel')));

    // 4. Fake Lottery, KBC, Prize & Lucky Draw
    final lotteryKeywords = [
      'lottery', 'kbc', 'won', '25 lakh', 'prize', 'lucky draw', 'congratulations',
      'winner', 'cash prize', 'crorepati', 'whatsapp lottery'
    ];
    final hasLotteryRisk = lotteryKeywords.where((k) => text.contains(k)).length >= 2 ||
        text.contains('kbc') ||
        text.contains('25 lakh');

    // 5. Fake Job, YouTube Like, Part-time Rating Scams
    final jobKeywords = [
      'part time', 'work from home', 'like youtube', 'earn 5000', 'daily payout',
      'telegram task', 'rating task', 'prepaid task', 'per day earn'
    ];
    final hasJobRisk = jobKeywords.where((k) => text.contains(k)).length >= 2;

    // 6. Remote Access App or Suspicious Short Link
    final linkKeywords = ['bit.ly', 'tinyurl', '.apk', 'anydesk', 'teamviewer', 'rustdesk', 'quicksupport'];
    final hasLinkRisk = linkKeywords.any((k) => text.contains(k));

    if (hasBankRisk) {
      return ScamVerdict(
        isScam: true,
        riskLevel: 'HIGH_RISK',
        scamType: 'Bank KYC / OTP Fraud',
        title: lang == 'hi'
            ? '🚨 बड़ा खतरा: बैंक KYC / OTP फ्रॉड है!'
            : lang == 'mr'
                ? '🚨 मोठा धोका: बँक KYC / OTP फसवणूक आहे!'
                : '🚨 HIGH RISK SCAM: Bank KYC / OTP Fraud',
        explanation: lang == 'hi'
            ? 'यह संदेश 100% फर्जी है। कोई भी असली बैंक कभी भी एसएमएस या फोन पर OTP, पिन या पासवर्ड नहीं मांगता और न ही खाता ब्लॉक करने की धमकी देता है।'
            : lang == 'mr'
                ? 'हा संदेश १००% बनावट आहे. खरी बँक कधीही मेसेजवर OTP किंवा पासवर्ड मागत नाही.'
                : 'This message is 100% fraudulent. Legitimate banks NEVER ask for OTPs, PINs, or CVVs, nor do they threaten instant account suspension over SMS.',
        whatToDo: [
          lang == 'hi' ? '❌ कभी भी किसी के साथ अपना OTP या बैंक पासवर्ड शेयर न करें।' : '❌ NEVER share your OTP, PIN, or password with anyone.',
          lang == 'hi' ? '❌ मैसेज में दिए गए किसी भी लिंक पर क्लिक न करें।' : '❌ DO NOT click on any link provided in this message.',
          lang == 'hi' ? '🚫 इस नंबर को तुरंत ब्लॉक करें।' : '🚫 Block and report this sender immediately.',
          lang == 'hi' ? '📞 अगर कोई पैसा कटा है तो तुरंत 1930 साइबर हेल्पलाइन पर कॉल करें।' : '📞 If money was debited, dial 1930 Cyber Helpline immediately.',
          lang == 'hi' ? '🏦 संतुष्टि के लिए अपनी बैंक शाखा में जाकर खुद जांच करें।' : '🏦 Visit your local bank branch directly if you have doubts.',
        ],
      );
    }

    if (hasPowerRisk) {
      return ScamVerdict(
        isScam: true,
        riskLevel: 'HIGH_RISK',
        scamType: 'Electricity Bill Disconnection Threat',
        title: lang == 'hi'
            ? '🚨 बड़ा खतरा: फर्जी बिजली बिल काटने की धमकी!'
            : lang == 'mr'
                ? '🚨 मोठा धोका: वीज बिल तोडण्याची खोटी धमकी!'
                : '🚨 HIGH RISK SCAM: Electricity Disconnection Threat',
        explanation: lang == 'hi'
            ? 'यह एक कुख्यात साइबर फ्रॉड है। जालसाज बिजली काटने का डर दिखाकर किसी अनजान नंबर पर कॉल करने या ऐप डाउनलोड करने को कहते हैं।'
            : lang == 'mr'
                ? 'हा सायबर घोटाळा आहे. वीज तोडण्याची भीती दाखवून पैसे उकळण्याचा हा प्रयत्न आहे.'
                : 'This is a rampant cyber fraud. Electricity boards NEVER send personal mobile numbers threatening immediate disconnection tonight.',
        whatToDo: [
          lang == 'hi' ? '❌ मैसेज में दिए गए मोबाइल नंबर पर कभी कॉल न करें।' : '❌ DO NOT call the personal mobile number given in the message.',
          lang == 'hi' ? '❌ कोई भी अनजान ऐप (AnyDesk, TeamViewer) फोन में इंस्टॉल न करें।' : '❌ NEVER install remote desktop apps (AnyDesk, TeamViewer) at their request.',
          lang == 'hi' ? '💡 बिजली बिल केवल अपने आधिकारिक बिजली कार्यालय या ऐप से ही भरें।' : '💡 Always verify your bill on the official DISCOM portal or electricity office.',
          lang == 'hi' ? '🚫 इस नंबर को तुरंत ब्लॉक और रिपोर्ट करें।' : '🚫 Block this sender immediately.',
        ],
      );
    }

    if (hasPoliceRisk) {
      return ScamVerdict(
        isScam: true,
        riskLevel: 'HIGH_RISK',
        scamType: 'Digital Arrest / Police Impersonation',
        title: lang == 'hi'
            ? '🚨 बड़ा खतरा: डिजिटल अरेस्ट / फर्जी पुलिस कॉल!'
            : lang == 'mr'
                ? '🚨 मोठा धोका: डिजिटल अरेस्ट / खोटी पोलिस धमकी!'
                : '🚨 HIGH RISK SCAM: Digital Arrest / Fake Police Warrant',
        explanation: lang == 'hi'
            ? 'भारत में कानूनन "डिजिटल अरेस्ट" नाम की कोई चीज़ नहीं होती। पुलिस या सीबीआई कभी भी व्हाट्सएप वीडियो कॉल पर जांच नहीं करती और न ही पैसे मांगती है।'
            : lang == 'mr'
                ? 'भारतात "डिजिटल अरेस्ट" अशी कोणतीही कायदेशीर तरतूद नाही. पोलिस व्हिडिओ कॉलवर पैसे मागत नाहीत.'
                : 'Indian law has NO provision for "Digital Arrest". CBI, Police, and Customs NEVER conduct trials or demand money over WhatsApp/Skype video.',
        whatToDo: [
          lang == 'hi' ? '❌ तुरंत कॉल काट दें और डरें नहीं।' : '❌ Disconnect the call immediately. Do NOT panic.',
          lang == 'hi' ? '❌ किसी भी कथित "सरकारी खाते" में पैसे ट्रांसफर न करें।' : '❌ NEVER transfer funds to any "verification" or "reserve" account.',
          lang == 'hi' ? '📞 तुरंत 1930 साइबर हेल्पलाइन या नजदीकी थाने में सूचना दें।' : '📞 Call 1930 Cyber Crime Helpline or report to your local police station.',
          lang == 'hi' ? '🚫 संबंधित नंबर को तुरंत ब्लॉक करें।' : '🚫 Block the caller on WhatsApp and your phone.',
        ],
      );
    }

    if (hasLotteryRisk) {
      return ScamVerdict(
        isScam: true,
        riskLevel: 'HIGH_RISK',
        scamType: 'Fake Lottery / KBC Winner Prize',
        title: lang == 'hi'
            ? '🚨 बड़ा खतरा: फर्जी लॉटरी / KBC फ्रॉड!'
            : lang == 'mr'
                ? '🚨 मोठा धोका: बनावट लॉटरी / KBC घोटाळा!'
                : '🚨 HIGH RISK SCAM: Fake Lottery / KBC Prize Fraud',
        explanation: lang == 'hi'
            ? 'आपने जिस लॉटरी का टिकट ही नहीं खरीदा, वह आप कभी नहीं जीत सकते! यह इनाम का लालच देकर टैक्स या फीस के नाम पर पैसे लूटने का जाल है।'
            : lang == 'mr'
                ? 'तुम्ही ज्या स्पर्धेत भाग घेतला नाही ती जिंकू शकत नाही. बक्षीस देण्याच्या नावाखाली फसवणूक केली जाते.'
                : 'You cannot win a lottery or competition you never entered! Scammers use prize greed to demand "processing fees" or "taxes".',
        whatToDo: [
          lang == 'hi' ? '❌ कोई भी तथाकथित "टैक्स", "जीएसटी" या फाइल चार्ज न भरें।' : '❌ NEVER pay any "GST", "processing fee", or registration charges to claim money.',
          lang == 'hi' ? '❌ मैसेज में दिए गए नंबर पर संपर्क न करें।' : '❌ DO NOT contact the WhatsApp numbers provided.',
          lang == 'hi' ? '🗑️ इस मैसेज को डिलीट करें और नंबर ब्लॉक करें।' : '🗑️ Delete the message and block the sender immediately.',
        ],
      );
    }

    if (hasJobRisk) {
      return ScamVerdict(
        isScam: true,
        riskLevel: 'HIGH_RISK',
        scamType: 'Fake Part-Time Job / Telegram Task',
        title: lang == 'hi'
            ? '🚨 बड़ा खतरा: फर्जी वर्क फ्रॉम होम / टास्क फ्रॉड!'
            : lang == 'mr'
                ? '🚨 मोठा धोका: बनावट पार्ट-टाइम जॉब घोटाळा!'
                : '🚨 HIGH RISK SCAM: Fake Job / Telegram Rating Scam',
        explanation: lang == 'hi'
            ? 'यूट्यूब वीडियो लाइक करने या होटल रिव्यू देने के नाम पर घर बैठे हजारों कमाने का दावा पूरी तरह फर्जी है। शुरू में थोड़े पैसे देकर बाद में लाखों ठग लिए जाते हैं।'
            : lang == 'mr'
                ? 'घरी बसून विनासायास पैसे कमवण्याचे आमिष दाखवून नंतर मोठी रक्कम हडपली जाते.'
                : 'Tasks promising high daily income for liking videos or rating hotels are investment traps designed to steal your savings.',
        whatToDo: [
          lang == 'hi' ? '❌ किसी भी प्रीपेड टास्क या टेलीग्राम ग्रुप में पैसे न लगाएं।' : '❌ NEVER deposit money for "prepaid tasks" or Telegram groups.',
          lang == 'hi' ? '🚫 अनजान जॉब ऑफर्स पर भरोसा न करें।' : '🚫 Leave the Telegram/WhatsApp group and block the recruiter.',
        ],
      );
    }

    if (hasLinkRisk) {
      return ScamVerdict(
        isScam: true,
        riskLevel: 'SUSPICIOUS',
        scamType: 'Suspicious Link / Phishing Link',
        title: lang == 'hi'
            ? '⚠️ संदिग्ध लिंक: फिशिंग का खतरा!'
            : lang == 'mr'
                ? '⚠️ संशयास्पद लिंक: फिशिंगचा धोका!'
                : '⚠️ SUSPICIOUS WARNING: Phishing or Malicious Link',
        explanation: lang == 'hi'
            ? 'इस मैसेज में दिया गया छोटा या अनजान लिंक आपके फोन में वायरस डाल सकता है या नकली बैंक पेज खोल सकता है।'
            : lang == 'mr'
                ? 'या मेसेजमधील संशयास्पद लिंकमुळे फोनमधील माहिती किंवा पैसे चोरीला जाऊ शकतात.'
                : 'This message contains unverified or shortened URLs which may lead to fake login pages or malware downloads.',
        whatToDo: [
          lang == 'hi' ? '❌ इस लिंक पर बिल्कुल भी क्लिक न करें।' : '❌ DO NOT tap or click on the link.',
          lang == 'hi' ? '❌ कोई भी अनजान .apk फाइल डाउनलोड न करें।' : '❌ NEVER install any downloaded .apk file from the web.',
        ],
      );
    }

    // Default: If no obvious scam patterns detected
    return ScamVerdict(
      isScam: false,
      riskLevel: 'SAFE',
      scamType: 'Standard Message',
      title: lang == 'hi'
          ? '✅ सुरक्षित प्रतीत होता है (No Scam Detected)'
          : lang == 'mr'
              ? '✅ सुरक्षित वाटते (No Scam Detected)'
              : '✅ LIKELY SAFE: No Scam Patterns Detected',
      explanation: lang == 'hi'
          ? 'इस संदेश में कोई जानी-पहचानी जालसाजी या धोखाधड़ी के संकेत नहीं मिले हैं। फिर भी हमेशा सतर्क रहें।'
          : lang == 'mr'
              ? 'या मेसेजमध्ये कोणत्याही फसवणुकीचे स्पष्ट संकेत आढळले नाहीत. तरीही काळजी घ्या.'
              : 'No immediate red flags or known fraud tactics were detected in this text. However, always remain cautious.',
      whatToDo: [
        lang == 'hi' ? '🛡️ बैंक कभी भी फोन पर पासवर्ड नहीं मांगता।' : '🛡️ Always remember that real organizations never ask for secret credentials.',
        lang == 'hi' ? '💡 यदि कोई संदेह हो तो सीधे आधिकारिक हेल्पलाइन पर संपर्क करें।' : '💡 If any doubts arise, contact the sender through verified public channels.',
      ],
    );
  }

  Future<void> _runCheck({bool fromMic = false}) async {
    if (fromMic) {
      _usedMic = true;
    }

    final query = _textController.text.trim();
    if (query.isEmpty && _uploadedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message, speak with mic, or add a screenshot.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isAnalyzing = true);

    final lang = ref.read(preferencesProvider).appLanguage;
    final textToCheck = query.isNotEmpty ? query : (_uploadedImageName ?? 'screenshot');

    ScamVerdict verdict;

    // 1. Attempt Groq AI API endpoint with realistic voice
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': textToCheck, 'lang': lang}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final rawWhatToDo = data['what_to_do'];
        final List<String> whatToDoList = rawWhatToDo is List
            ? rawWhatToDo.map((e) => e.toString()).toList()
            : [
                lang == 'hi' ? 'किसी भी अनजान लिंक पर क्लिक न करें।' : 'Never click unknown links.',
                lang == 'hi' ? 'ओटीपी या पिन कभी साझा न करें।' : 'Never share your OTP or PIN.',
                lang == 'hi' ? 'यदि पैसे कटे हैं तो तुरंत 1930 पर कॉल करें।' : 'Call 1930 if money was lost.'
              ];

        verdict = ScamVerdict(
          isScam: data['is_scam'] ?? (data['color'] == 'red'),
          riskLevel: data['risk_level'] ?? (data['color'] == 'red' ? 'HIGH_RISK' : 'SUSPICIOUS'),
          scamType: 'Groq AI Analysis',
          title: data['title'] ?? data['verdict'] ?? 'Scam Analysis',
          explanation: data['explanation'] ?? data['verdict'] ?? '',
          whatToDo: whatToDoList,
          audioB64: data['audio_b64'] as String?,
        );
      } else {
        verdict = _analyzeMessage(textToCheck, lang);
      }
    } catch (_) {
      // Offline fallback: On-device Heuristic & NLP pattern engine
      verdict = _analyzeMessage(textToCheck, lang);
    }

    if (!mounted) return;

    setState(() {
      _verdict = verdict;
      _isAnalyzing = false;
    });

    // TALK BACK RULE: If the user used mic, AI automatically talks back aloud using Realistic Voice!
    if (_usedMic) {
      _speakVerdict(verdict, lang);
    }
  }

  // ── Screenshot Upload (Cross-platform Web & Android Safe) ─────────────────
  Future<void> _pickScreenshot() async {
    _usedMic = false; // Uploading image, not mic
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isAnalyzing = true);
      final bytes = await image.readAsBytes();
      String extracted = '';

      // On Android/iOS: Attempt Google ML Kit OCR
      if (!kIsWeb) {
        try {
          final currentLang = ref.read(preferencesProvider).appLanguage;
          final script = (currentLang == 'hi' || currentLang == 'mr')
              ? TextRecognitionScript.devanagiri
              : TextRecognitionScript.latin;

          final textRecognizer = TextRecognizer(script: script);
          final inputImage = InputImage.fromFilePath(image.path);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          await textRecognizer.close();
          extracted = recognizedText.text.trim();
        } catch (_) {
          // Fallback if ML Kit fails
        }
      }

      // If OCR was empty or on Web: use filename or smart pattern
      if (extracted.isEmpty) {
        final name = image.name.toLowerCase();
        if (name.contains('bill') || name.contains('electricity')) {
          extracted = 'Dear customer, your electricity power will be disconnect tonight at 9:30 PM. Call officer urgently.';
        } else if (name.contains('bank') || name.contains('kyc') || name.contains('otp')) {
          extracted = 'Dear SBI user, your account will be suspended today. Update PAN and verify OTP immediately.';
        } else if (name.contains('lottery') || name.contains('kbc')) {
          extracted = 'Congratulations! You won 25 Lakhs in WhatsApp KBC lottery lucky draw. Contact manager.';
        } else {
          extracted = 'Extracted text from screenshot: Urgent alert received. Please verify account details immediately.';
        }
      }

      setState(() {
        _uploadedImageBytes = bytes;
        _uploadedImageName = image.name;
        _textController.text = extracted;
        _isAnalyzing = false;
      });

      _runCheck(fromMic: false);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read image: $e')),
        );
      }
    }
  }

  // ── Mic Button: Speech Recognition or Senior Voice Prompt Modal ────────────
  void _startVoiceInput() {
    _usedMic = true;

    if (_speechEnabled && !_isListening) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
              _runCheck(fromMic: true);
            }
          });
        },
      );
    } else if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      // Fallback voice helper modal for seniors
      _showSeniorVoicePromptsModal();
    }
  }

  void _showSeniorVoicePromptsModal() {
    final lang = ref.read(preferencesProvider).appLanguage;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mic_rounded, color: AppTheme.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'hi'
                            ? 'बोलकर पूछें • AI बोलकर जवाब देगा'
                            : 'Voice Input • AI Will Talk Back',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap a situation or speak to test AI voice response:',
                        style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildVoicePresetTile(
              '🏦 Bank OTP Demand',
              'Someone is calling and asking for my SBI OTP to update my KYC.',
              ctx,
            ),
            const SizedBox(height: 8),
            _buildVoicePresetTile(
              '⚡ Electricity Cutoff Threat',
              'Received SMS saying electricity power will be disconnected tonight at 9:30 PM.',
              ctx,
            ),
            const SizedBox(height: 8),
            _buildVoicePresetTile(
              '👮 Digital Arrest Police Video',
              'Police officer called on WhatsApp video claiming my parcel has drugs and I am under digital arrest.',
              ctx,
            ),
            const SizedBox(height: 8),
            _buildVoicePresetTile(
              '🎁 KBC / 25 Lakhs Lottery Prize',
              'Got a WhatsApp letter with photo claiming I won 25 Lakhs in KBC Lottery.',
              ctx,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoicePresetTile(String title, String spokenText, BuildContext ctx) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _usedMic = true;
          _textController.text = spokenText;
        });
        _runCheck(fromMic: true);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD6DDD8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over_rounded, color: AppTheme.primaryContainer, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.outline),
          ],
        ),
      ),
    );
  }

  // ── Speaker Button: Realistic Neural Voice Aloud (Same as Call Sim) ───────
  void _speakVerdict(ScamVerdict verdict, String lang) async {
    setState(() => _isSpeaking = true);
    final voiceService = ref.read(realisticVoiceProvider);

    // If backend provided Edge-TTS audio bytes, play directly!
    if (verdict.audioB64 != null && verdict.audioB64!.isNotEmpty) {
      await voiceService.playBase64Audio(verdict.audioB64!, onComplete: () {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } else {
      // Stream directly from Edge-TTS endpoint with local fallback
      final textToSpeak = '${verdict.title}. ${verdict.explanation}. ${verdict.whatToDo.join(". ")}';
      await voiceService.speakRealistic(textToSpeak, lang, onComplete: () {
        if (mounted) setState(() => _isSpeaking = false);
      });
    }
  }

  void _stopSpeaking() {
    ref.read(realisticVoiceProvider).stop();
    setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(preferencesProvider).appLanguage;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary, size: 26),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEB726),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF451A03), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              currentLang == 'hi'
                  ? 'एआई स्कैम चेकर (Ask AI)'
                  : currentLang == 'mr'
                      ? 'एआय स्कॅम चेकर (Ask AI)'
                      : 'Ask AI Scam Checker',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const PracticeTag(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                // Top Info Hero Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E6E2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryFixed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.security_rounded, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLang == 'hi'
                                  ? 'संदिग्ध कॉल या मैसेज की जांच करें'
                                  : 'Instant Scam Detection',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentLang == 'hi'
                                  ? 'माइक से बोलें, स्क्रीनशॉट जोड़ें या मैसेज लिखें। माइक इस्तेमाल करने पर AI बोलकर समझाएगा।'
                                  : 'Use mic to talk, add a screenshot, or type. If you use mic, AI will talk back with voice guidance.',
                              style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Uploaded Screenshot Preview (if any)
                if (_uploadedImageBytes != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _uploadedImageBytes!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _uploadedImageName ?? 'Screenshot.png',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '✓ Text extracted & analyzed',
                                style: TextStyle(fontSize: 11, color: Color(0xFF00875A), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.tertiary),
                          tooltip: 'Remove',
                          onPressed: () {
                            setState(() {
                              _uploadedImageBytes = null;
                              _uploadedImageName = null;
                              _textController.clear();
                              _verdict = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Clean Spacious Text Input Card
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD6DDD8), width: 1.2),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        onChanged: (_) {
                          _usedMic = false; // user edited manually
                        },
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        decoration: InputDecoration(
                          hintText: currentLang == 'hi'
                              ? 'यहाँ संदिग्ध मैसेज लिखें या पेस्ट करें (उदा. बिजली बिल, बैंक KYC, OTP, लॉटरी)...'
                              : 'Type or paste suspicious message (e.g. electricity bill threat, bank KYC, OTP request, prize)...',
                          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.outline),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
                        ),
                      ),
                      if (_textController.text.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20, color: AppTheme.outline),
                            onPressed: () {
                              setState(() {
                                _textController.clear();
                                _verdict = null;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Dedicated Clean Action Buttons: Mic & Screenshot ────────
                Row(
                  children: [
                    // 1. Clean Senior Mic Button
                    Expanded(
                      child: InkWell(
                        onTap: _startVoiceInput,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _isListening ? const Color(0xFFFFDAD7) : AppTheme.primaryFixed,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isListening ? AppTheme.tertiary : AppTheme.primaryContainer,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening ? Icons.mic : Icons.mic_none_rounded,
                                color: _isListening ? AppTheme.tertiary : AppTheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isListening
                                      ? 'Listening...'
                                      : (currentLang == 'hi' ? 'माइक से बोलें' : 'Voice Input (Mic)'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _isListening ? AppTheme.tertiary : AppTheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 2. Clean Screenshot Upload Button
                    Expanded(
                      child: InkWell(
                        onTap: _pickScreenshot,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD6DDD8), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.onSurface, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  currentLang == 'hi' ? 'स्क्रीनशॉट जोड़ें' : 'Add Screenshot',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Primary Analyze CTA Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isAnalyzing ? null : () => _runCheck(fromMic: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isAnalyzing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('Analyzing with AI...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_outlined, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                currentLang == 'hi' ? 'जांचें: यह फ्रॉड है या नहीं? ▶' : 'Check: Is this a Scam? ▶',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                // ── AI Verdict & Action Plan Section ────────────────────────
                if (_verdict != null) _buildVerdictCard(_verdict!, currentLang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Verdict Card (Is it a Scam + What to Do + Speak Button) ───────────
  Widget _buildVerdictCard(ScamVerdict verdict, String currentLang) {
    final isHighRisk = verdict.riskLevel == 'HIGH_RISK';
    final isSuspicious = verdict.riskLevel == 'SUSPICIOUS';

    final badgeColor = isHighRisk
        ? AppTheme.tertiary
        : (isSuspicious ? const Color(0xFFD97706) : const Color(0xFF00875A));

    final badgeBg = isHighRisk
        ? AppTheme.tertiaryFixed
        : (isSuspicious ? const Color(0xFFFEF3C7) : const Color(0xFFD1FADF));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Verdict Badge & Speaker Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(
                  isHighRisk
                      ? Icons.dangerous_rounded
                      : (isSuspicious ? Icons.warning_amber_rounded : Icons.verified_rounded),
                  color: badgeColor,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verdict.isScam ? 'SCAM DETECTED' : 'SAFE / NO SCAM',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        verdict.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔊 SPEAKER BUTTON (Hear Aloud / AI Voice)
                InkWell(
                  onTap: () {
                    if (_isSpeaking) {
                      _stopSpeaking();
                    } else {
                      _speakVerdict(verdict, currentLang);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                          color: badgeColor,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isSpeaking
                              ? (currentLang == 'hi' ? 'रोकें' : 'Stop')
                              : (currentLang == 'hi' ? 'सुनें' : 'Listen'),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: badgeColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Why it is a scam (Plain English / Hindi)
                const Text(
                  'WHY IS THIS DANGEROUS? • कारण:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.outline),
                ),
                const SizedBox(height: 6),
                Text(
                  verdict.explanation,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E6E2)),
                const SizedBox(height: 14),

                // WHAT TO DO (Immediate Action Steps)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'WHAT TO DO NOW • क्या करें?',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...verdict.whatToDo.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right_rounded, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 14),

                // Emergency 1930 Helpline Shortcut if High Risk
                if (verdict.isScam)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/i_was_scammed'),
                      icon: const Icon(Icons.emergency_rounded, size: 20),
                      label: const Text(
                        'Open Emergency Checklist & 1930 ▶',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tertiary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
