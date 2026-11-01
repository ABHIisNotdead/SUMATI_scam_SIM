/// Utility for detecting whether a user recognized or called out a scam
/// across speech transcripts (voice call) and chat messages (WhatsApp / SMS).
class ScamDetectionChecker {
  static const List<String> _scamKeywords = [
    // English
    'scam',
    'scammer',
    'fraud',
    'fraudster',
    'fake',
    'cyber crime',
    'cyber cell',
    'cybercrime',
    '1930',
    'police complaint',
    'reporting you',
    'report to police',
    'report you',
    'not giving otp',
    'not sharing otp',
    'will not give otp',
    'won\'t give otp',
    'never share otp',
    'no otp',
    'fake warrant',
    'fake police',
    'fake cbi',
    'fake arrest',
    'fake call',
    'trick',
    'imposter',
    'cheater',

    // Hindi & Hinglish
    'धोखा',
    'धोखेबाज',
    'dhokha',
    'dhokhebaz',
    'फ़र्ज़ी',
    'फर्जी',
    'farzi',
    'नकली',
    'nakli',
    'स्कैम',
    'फ्रॉड',
    'scam hai',
    'fraud hai',
    'साइबर',
    'cyber cell',
    'पुलिस शिकायत',
    'शिकायत करूंगा',
    'complaint karunga',
    'police ko phone',
    'ओटीपी नहीं',
    'otp nahi',
    'पैसे नहीं दूंगा',
    'paise nahi dunga',
    'चोर',
    'chor',
    'lutere',
    'lute',

    // Marathi
    'फसवणूक',
    'fasavnuk',
    'खोटं',
    'khota',
    'पोलीस तक्रार',
    'सायबर',
    'ओटीपी देणार नाही',
    'पैसे देणार नाही',
  ];

  /// Returns true if the user's message indicates they detected/recognized the fraud.
  static bool isScamRecognized(String text) {
    if (text.trim().isEmpty) return false;
    final lower = text.toLowerCase().trim();
    for (final kw in _scamKeywords) {
      if (lower.contains(kw.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Returns a human-readable explanation of how the user successfully recognized the fraud.
  static String getRecognizedExplanation(String text) {
    return 'Scam Detected: User identified suspicious fraud tactics and actively refused compliance ("${text.trim()}").';
  }
}

