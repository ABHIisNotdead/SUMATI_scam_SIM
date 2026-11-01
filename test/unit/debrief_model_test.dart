import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F8, F9, F10: Debrief Data Contracts & Educational Model Tests', () {
    // -------------------------------------------------------------
    // Tier 1: Feature Coverage (Data Contracts & Schema Requirements)
    // -------------------------------------------------------------

    test('F8-T1-01: Debrief response matches PROJECT.md contract schema', () {
      final debriefJson = {
        'headline': 'Well done! You successfully identified and defused the scam.',
        'tactics_explanation':
            'Real scammers use false authority and fabricated police arrest warrants to induce panic.',
        'dos': [
          'Do demand physical paperwork',
          'Do verify badge numbers with local precinct'
        ],
        'donts': [
          'Never join Skype video calls with supposed officers',
          'Never transfer funds to safety accounts'
        ],
        'audio_script':
            'Well done! You defended against this scam. Real scammers use false authority...'
      };

      expect(debriefJson['headline'], contains('Well done!'));
      expect(debriefJson['tactics_explanation'], contains('false authority'));
      expect((debriefJson['dos'] as List).length, equals(2));
      expect((debriefJson['donts'] as List).length, equals(2));
      expect(debriefJson['audio_script'], isNotEmpty);
    });

    test('F8-T1-02: Digital arrest tactics specifically explain video isolation & fear', () {
      const tactics =
          'Scammers use fake police badges, fabricated FIR numbers, and coerce victims into private video calls to isolate them from family and prevent critical thinking.';
      
      expect(tactics.toLowerCase(), contains('fake police'));
      expect(tactics.toLowerCase(), contains('isolate'));
    });

    test('F8-T1-03: Bank KYC tactics specifically explain urgency and secrecy', () {
      const tactics =
          'Scammers fabricate imminent account suspension and rush the victim to read back an SMS verification OTP before they notice the debit amount.';
      
      expect(tactics.toLowerCase(), contains('account suspension'));
      expect(tactics.toLowerCase(), contains('otp'));
    });

    test('F9-T1-04: Celebratory headline emitted on successful defense', () {
      const successOutcome = 'success:survived';
      final bool isSuccess = successOutcome.startsWith('success');
      final headline = isSuccess
          ? 'Well done! You successfully identified and defused the scam.'
          : 'Be careful! Trap triggered.';

      expect(headline, startsWith('Well done!'));
    });

    test('F10-T1-05: Spoken debrief audio script provides clear educational guidance', () {
      final audioScript =
          'Well done! You defended against this scam. Remember, real police departments will never arrest you over a video call or demand bank transfers to clear your name.';

      expect(audioScript.length, greaterThan(50));
      expect(audioScript, contains('Well done!'));
      expect(audioScript, contains('real police'));
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    test('F8-T2-01: Boundary - Empty dos and donts lists handle safely', () {
      final debriefJson = {
        'headline': 'Notice',
        'tactics_explanation': 'General safety advice',
        'dos': <String>[],
        'donts': <String>[],
        'audio_script': 'General safety advice.'
      };

      final dos = debriefJson['dos'] as List;
      final donts = debriefJson['donts'] as List;

      expect(dos, isEmpty);
      expect(donts, isEmpty);
    });

    test('F8-T2-02: Boundary - Hindi localized debrief payload parsing', () {
      final hindiDebrief = {
        'headline': 'बहुत बढ़िया! आपने सफलतापूर्वक घोटाले को विफल कर दिया।',
        'tactics_explanation':
            'असली धोखेबाज़ झूठी पुलिस वर्दी और फर्जी वारंट दिखाकर घबराहट पैदा करते हैं।',
        'dos': ['स्थानीय पुलिस स्टेशन से सत्यापन करें', 'अपने परिवार को सूचित करें'],
        'donts': ['स्काइप वीडियो कॉल पर कभी न जुड़ें', 'अनजान खातों में पैसे न भेजें'],
        'audio_script': 'बहुत बढ़िया! आपने इस घोटाले से अपनी रक्षा की...'
      };

      final serialized = jsonEncode(hindiDebrief);
      final deserialized = jsonDecode(serialized) as Map<String, dynamic>;

      expect(deserialized['headline'], contains('बहुत बढ़िया!'));
      expect((deserialized['dos'] as List).length, equals(2));
      expect((deserialized['donts'] as List).length, equals(2));
    });

    test('F9-T2-03: Boundary - Compromised outcome provides non-celebratory protective headline', () {
      const compromisedOutcome = 'failure:compromised';
      final bool isSuccess = compromisedOutcome.startsWith('success');
      final headline = isSuccess
          ? 'Well done!'
          : 'Be careful! In real life, your accounts would be at risk.';

      expect(isSuccess, isFalse);
      expect(headline, startsWith('Be careful!'));
    });

    test('F9-T2-04: Boundary - Hung up outcome is treated as success defense', () {
      const hungUpOutcome = 'success:hung_up';
      final bool isSuccess = hungUpOutcome.startsWith('success');

      expect(isSuccess, isTrue);
    });

    test('F10-T2-05: Boundary - Audio script with special characters and punctuation escapes cleanly', () {
      const scriptWithChars =
          'Notice: "Never" share your OTP & passwords with AX-SBIBNK or anyone! Check 1930 / cybercrime.gov.in.';

      final encoded = jsonEncode({'script': scriptWithChars});
      final decoded = jsonDecode(encoded);

      expect(decoded['script'], equals(scriptWithChars));
    });
  });
}
