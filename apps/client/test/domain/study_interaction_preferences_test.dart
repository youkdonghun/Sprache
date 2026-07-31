import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';

void main() {
  test('interaction preferences survive a JSON round trip', () {
    final preferences = StudyInteractionPreferences(
      autoPlayQuestionAudio: true,
      autoPlayAnswerAudio: true,
      preferOfflineVoice: false,
      audioRepeatCount: 3,
      showKoreanReading: false,
      showNativeReading: false,
      answerDirection: StudyAnswerDirection.meaningToLearning,
      choiceLayout: StudyChoiceLayout.grid,
      shuffleChoices: false,
      autoAdvanceCorrect: true,
      autoAdvanceDelayMs: 1450,
      updatedAt: DateTime.utc(2026, 7, 31, 10),
    );

    final restored = StudyInteractionPreferences.fromJson(preferences.toJson());

    expect(restored.autoPlayQuestionAudio, isTrue);
    expect(restored.autoPlayAnswerAudio, isTrue);
    expect(restored.preferOfflineVoice, isFalse);
    expect(restored.audioRepeatCount, 3);
    expect(restored.showKoreanReading, isFalse);
    expect(restored.showNativeReading, isFalse);
    expect(restored.answerDirection, StudyAnswerDirection.meaningToLearning);
    expect(restored.choiceLayout, StudyChoiceLayout.grid);
    expect(restored.shuffleChoices, isFalse);
    expect(restored.autoAdvanceCorrect, isTrue);
    expect(restored.autoAdvanceDelayMs, 1450);
    expect(restored.updatedAt, DateTime.utc(2026, 7, 31, 10));
  });

  test('interaction numeric values clamp and unknown enums fall back', () {
    final restored = StudyInteractionPreferences.fromJson({
      'audioRepeatCount': 99,
      'autoAdvanceDelayMs': 10,
      'answerDirection': 'sideways',
      'choiceLayout': 'carousel',
    });

    expect(restored.audioRepeatCount, 3);
    expect(restored.autoAdvanceDelayMs, 300);
    expect(restored.answerDirection, StudyAnswerDirection.mixed);
    expect(restored.choiceLayout, StudyChoiceLayout.automatic);
  });
}
