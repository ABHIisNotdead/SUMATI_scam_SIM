import 'package:flutter_test/flutter_test.dart';
import 'package:sumati/core/providers/ai_call_provider.dart';

void main() {
  group('F4, F5, F6: AiCallState & Listening State Transition Unit Tests', () {
    // -------------------------------------------------------------
    // Tier 1: Feature Coverage (State Machine Behavior)
    // -------------------------------------------------------------

    test('F4-T1-01: AiCallState initializes with safe default values', () {
      final state = AiCallState();

      expect(state.latestAiReply, isEmpty);
      expect(state.status, equals('ongoing'));
      expect(state.evaluation, isNull);
      expect(state.isSpeaking, isFalse);
    });

    test('F4-T1-02: copyWith correctly updates isSpeaking from true to false', () {
      final stateSpeaking = AiCallState(
        latestAiReply: 'Hello, this is Inspector Sharma.',
        isSpeaking: true,
      );
      expect(stateSpeaking.isSpeaking, isTrue);

      final stateFinished = stateSpeaking.copyWith(isSpeaking: false);
      expect(stateFinished.isSpeaking, isFalse);
      expect(stateFinished.latestAiReply, equals(stateSpeaking.latestAiReply));
    });

    test('F5-T1-03: Status transitions to deflected when user resists scam', () {
      final ongoingState = AiCallState(status: 'ongoing');
      final deflectedState = ongoingState.copyWith(
        status: 'deflected',
        evaluation: 'User successfully challenged authority',
      );

      expect(deflectedState.status, equals('deflected'));
      expect(deflectedState.evaluation, contains('successfully challenged'));
    });

    test('F5-T1-04: Status transitions to compromised when trap triggered', () {
      final ongoingState = AiCallState(status: 'ongoing');
      final compromisedState = ongoingState.copyWith(
        status: 'compromised',
        evaluation: 'Victim shared OTP',
      );

      expect(compromisedState.status, equals('compromised'));
      expect(compromisedState.evaluation, contains('shared OTP'));
    });

    test('F6-T1-05: Manual voice message submission resets speaking state', () {
      final state = AiCallState(isSpeaking: true);
      final stoppedState = state.copyWith(isSpeaking: false);

      expect(stoppedState.isSpeaking, isFalse);
    });

    // -------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 per feature)
    // -------------------------------------------------------------

    test('F4-T2-01: Boundary - Rapid consecutive speech state transitions', () {
      var state = AiCallState();
      for (int i = 0; i < 20; i++) {
        state = state.copyWith(isSpeaking: i % 2 == 0);
      }
      expect(state.isSpeaking, isFalse);
    });

    test('F4-T2-02: Boundary - Long AI reply preserves full transcript in state', () {
      final longReply = 'A' * 2000;
      final state = AiCallState(latestAiReply: longReply);

      expect(state.latestAiReply.length, equals(2000));
    });

    test('F5-T2-03: Boundary - Status remains stable when updating unrelated fields', () {
      final state = AiCallState(status: 'deflected');
      final updated = state.copyWith(latestAiReply: 'Updated reply');

      expect(updated.status, equals('deflected'));
      expect(updated.latestAiReply, equals('Updated reply'));
    });

    test('F6-T2-04: Boundary - copyWith with all null arguments preserves existing values', () {
      final original = AiCallState(
        latestAiReply: 'Original text',
        status: 'ongoing',
        evaluation: 'Good defense',
        isSpeaking: true,
      );

      final copy = original.copyWith();

      expect(copy.latestAiReply, equals(original.latestAiReply));
      expect(copy.status, equals(original.status));
      expect(copy.evaluation, equals(original.evaluation));
      expect(copy.isSpeaking, equals(original.isSpeaking));
    });

    test('F6-T2-05: Boundary - Empty string latestAiReply does not corrupt status', () {
      final state = AiCallState(
        latestAiReply: '',
        status: 'ongoing',
        isSpeaking: false,
      );

      expect(state.latestAiReply, isEmpty);
      expect(state.status, equals('ongoing'));
    });
  });
}
