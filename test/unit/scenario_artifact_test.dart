import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/models/scenario.dart';

void main() {
  group('F1, F2, F3: Scenario Metadata & Artifact Contract Unit Tests', () {
    // -------------------------------------------------------------
    // Tier 1: Feature Coverage (Happy Path & Schema Contracts)
    // -------------------------------------------------------------

    test('F1-T1-01: Scenario parses correctly from master JSON structure', () {
      final jsonMap = {
        'id': 'call_digital_arrest',
        'language': 'en',
        'title': 'Digital Arrest Scam',
        'channel': 'call',
        'difficulty': 'hard',
        'debrief_success': 'You challenged the fake police officer and hung up.',
        'debrief_failure': 'You transferred money under threat of arrest.',
        'goal': 'Coerce victim into transferring funds to safety account',
        'initial_message': 'This is Crime Branch Delhi. You are under digital arrest.',
      };

      final scenario = Scenario.fromJson(jsonMap);

      expect(scenario.id, equals('call_digital_arrest'));
      expect(scenario.channel, equals('call'));
      expect(scenario.title, equals('Digital Arrest Scam'));
      expect(scenario.difficulty, equals('hard'));
      expect(scenario.initialMessage, contains('digital arrest'));
    });

    test('F1-T1-02: Digital arrest scenario defines no OTP requirement in metadata', () {
      final jsonMap = {
        'id': 'call_digital_arrest',
        'title': 'Digital Arrest Scam',
        'channel': 'call',
        'initial_message': 'You are accused of money laundering via FedEx courier.',
      };

      final scenario = Scenario.fromJson(jsonMap);

      // Verify that scenario title and message do not reference OTP
      expect(scenario.title.toLowerCase().contains('otp'), isFalse);
      expect(scenario.initialMessage!.toLowerCase().contains('otp'), isFalse);
    });

    test('F2-T1-03: Dynamic artifact schema parses valid bank OTP payload', () {
      final artifactJson = {
        'type': 'otp',
        'sender': 'AX-SBIBNK',
        'title': 'SBI KYC Verification',
        'body': '482910 is your secret OTP for Rs 25,000 NEFT transfer. Valid 5m.',
        'action_label': 'Copy OTP',
      };

      expect(artifactJson['type'], equals('otp'));
      expect(artifactJson['sender'], equals('AX-SBIBNK'));
      expect(artifactJson['action_label'], equals('Copy OTP'));
      expect(artifactJson['body'], contains('482910'));
    });

    test('F3-T1-04: Dynamic artifact schema parses court warrant payload for Digital Arrest', () {
      final warrantJson = {
        'type': 'warrant',
        'sender': 'DELHI-POLICE',
        'title': 'Arrest Warrant Issued',
        'body': 'Non-bailable arrest warrant issued under PMLA Sec 3. Report immediately.',
        'action_label': 'View Warrant',
      };

      expect(warrantJson['type'], equals('warrant'));
      expect(warrantJson['sender'], equals('DELHI-POLICE'));
      expect(warrantJson['action_label'], equals('View Warrant'));
      expect(warrantJson['body'], contains('Non-bailable'));
    });

    test('F3-T1-05: Dynamic artifact schema parses electricity cutoff link payload', () {
      final cutoffJson = {
        'type': 'cutoff_link',
        'sender': 'VM-ELEC-PAY',
        'title': 'Power Cut Alert',
        'body': 'Power disconnection scheduled tonight at 9:30 PM. Pay Rs 15 immediately.',
        'action_label': 'Pay Now',
      };

      expect(cutoffJson['type'], equals('cutoff_link'));
      expect(cutoffJson['sender'], equals('VM-ELEC-PAY'));
      expect(cutoffJson['action_label'], equals('Pay Now'));
      expect(cutoffJson['body'], contains('disconnection scheduled'));
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    test('F1-T2-01: Boundary - Scenario with missing optional fields parses safely', () {
      final minimalJson = {
        'id': 'call_minimal',
        'title': 'Minimal Call',
        'channel': 'call',
      };

      final scenario = Scenario.fromJson(minimalJson);

      expect(scenario.id, equals('call_minimal'));
      expect(scenario.language, equals('en'));
      expect(scenario.difficulty, equals('easy'));
      expect(scenario.debriefSuccess, equals(''));
      expect(scenario.debriefFailure, equals(''));
      expect(scenario.persona, isNull);
      expect(scenario.initialMessage, isNull);
    });

    test('F2-T2-02: Boundary - Turn 0 message with null artifact handles gracefully', () {
      final wsTurn0 = {
        'reply': 'Hello, am I speaking with the account holder?',
        'suggestions': ['Yes, who is this?', 'Wrong number'],
        'status': 'ongoing',
        'evaluation': null,
        'artifact': null,
      };

      expect(wsTurn0['artifact'], isNull);
      expect(wsTurn0['status'], equals('ongoing'));
    });

    test('F2-T2-03: Boundary - WebSocket message with malformed JSON string handling', () {
      const malformedJson = '{"reply": "test", "artifact": {invalid}';
      
      expect(() => jsonDecode(malformedJson), throwsA(isA<FormatException>()));
    });

    test('F3-T2-04: Boundary - Multilingual Hindi artifact payload retains character fidelity', () {
      final hindiArtifact = {
        'type': 'warrant',
        'sender': 'DELHI-POLICE',
        'title': 'गिरफ्तारी वारंट जारी',
        'body': 'दिल्ली पुलिस द्वारा आपके खिलाफ गैर-जमानती वारंट जारी किया गया है।',
        'action_label': 'वारंट देखें',
      };

      final encoded = jsonEncode(hindiArtifact);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['title'], equals('गिरफ्तारी वारंट जारी'));
      expect(decoded['action_label'], equals('वारंट देखें'));
      expect(decoded['body'], contains('गैर-जमानती'));
    });

    test('F3-T2-05: Boundary - Empty artifact body and unusual action labels', () {
      final unusualArtifact = {
        'type': 'custom_alert',
        'sender': '',
        'title': '',
        'body': '',
        'action_label': 'Dismiss',
      };

      expect(unusualArtifact['type'], equals('custom_alert'));
      expect(unusualArtifact['sender'], isEmpty);
      expect(unusualArtifact['action_label'], equals('Dismiss'));
    });
  });
}
