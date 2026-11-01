import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/utils/scam_detection_checker.dart';

void main() {
  group('Phase 2: ScamDetectionChecker Unit Tests', () {
    test('detects English scam recognition phrases', () {
      expect(ScamDetectionChecker.isScamRecognized('This is clearly a scam'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('You are a fraudster, stop calling'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('I will not give otp to anyone'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('Calling 1930 cyber crime helpline'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('Fake arrest warrant from fake cbi'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('Reporting you to police complaint cell'), isTrue);
    });

    test('detects Hindi & Hinglish scam recognition phrases', () {
      expect(ScamDetectionChecker.isScamRecognized('यह एक धोखा है'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('फ़र्ज़ी पुलिस वाला है तू'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('ओटीपी नहीं दूंगा कभी भी'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('police complaint karunga abhi'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('chor ho tum log'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('nakli CBI order hai ye'), isTrue);
    });

    test('detects Marathi scam recognition phrases', () {
      expect(ScamDetectionChecker.isScamRecognized('ही मोठी फसवणूक आहे'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('हे खोटं आहे, पोलीस तक्रार करणार'), isTrue);
      expect(ScamDetectionChecker.isScamRecognized('ओटीपी देणार नाही मी'), isTrue);
    });

    test('returns false for normal conversation or compliance', () {
      expect(ScamDetectionChecker.isScamRecognized('Hello who is speaking?'), isFalse);
      expect(ScamDetectionChecker.isScamRecognized('Yes, please tell me the process'), isFalse);
      expect(ScamDetectionChecker.isScamRecognized('My electricity was cut off?'), isFalse);
      expect(ScamDetectionChecker.isScamRecognized('Where should I send the form?'), isFalse);
      expect(ScamDetectionChecker.isScamRecognized(''), isFalse);
      expect(ScamDetectionChecker.isScamRecognized('   '), isFalse);
    });

    test('generates recognized explanation message', () {
      final msg = ScamDetectionChecker.getRecognizedExplanation('This is a scam');
      expect(msg, contains('Scam Detected'));
      expect(msg, contains('This is a scam'));
    });
  });
}

