import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
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
      practiceCatalog: const PracticeCatalogPreferences(
        favoriteActivityIds: {'/study?mode=meaning'},
        hiddenActivityIds: {'/path'},
        recentActivityIds: ['/study?mode=meaning'],
        favoriteActivityOrder: ['/study?mode=meaning'],
        quickLaunchActivityIds: {'/study?mode=meaning'},
        launchByActivityId: {
          '/study?mode=meaning': PracticeLaunchPreferences(
            length: PracticeSessionLength.fiveMinutes,
            difficulty: PracticeDifficultyPreset.challenge,
            historyScope: PracticeHistoryScope.wrongOnly,
            queueOrder: PracticeQueueOrder.newFirst,
            answerDirection: StudyAnswerDirection.meaningToLearning,
            gradingStrictness: StudyGradingStrictness.strict,
            choiceCount: 6,
            recordProgress: false,
            hintsEnabled: false,
            autoAdvance: true,
            soundEnabled: true,
            largeControls: true,
          ),
        },
      ),
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
    expect(restored.practiceCatalog.favoriteActivityIds, {'meaning-choice'});
    expect(restored.practiceCatalog.hiddenActivityIds, {'course-path'});
    expect(restored.practiceCatalog.recentActivityIds, ['meaning-choice']);
    expect(restored.practiceCatalog.favoriteActivityOrder, ['meaning-choice']);
    expect(restored.practiceCatalog.quickLaunchActivityIds, {'meaning-choice'});
    final launch = restored.practiceCatalog.launchFor('/study?mode=meaning');
    expect(launch.length, PracticeSessionLength.fiveMinutes);
    expect(launch.difficulty, PracticeDifficultyPreset.challenge);
    expect(launch.historyScope, PracticeHistoryScope.wrongOnly);
    expect(launch.queueOrder, PracticeQueueOrder.newFirst);
    expect(launch.gradingStrictness, StudyGradingStrictness.strict);
    expect(launch.choiceCount, 6);
    expect(launch.recordProgress, isFalse);
    expect(launch.hintsEnabled, isFalse);
    expect(launch.autoAdvance, isTrue);
    expect(launch.soundEnabled, isTrue);
    expect(launch.largeControls, isTrue);
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

  test('malformed numeric types fall back without breaking hydration', () {
    final restored = StudyInteractionPreferences.fromJson({
      'audioRepeatCount': 'three',
      'autoAdvanceDelayMs': true,
      'practiceCatalog': {
        'launchByActivityId': {
          'mixed-quiz': {'itemCount': 'ten', 'choiceCount': false},
        },
      },
    });

    expect(restored.audioRepeatCount, 1);
    expect(restored.autoAdvanceDelayMs, 900);
    final launch = restored.practiceCatalog.launchFor('mixed-quiz');
    expect(launch.itemCount, 10);
    expect(launch.choiceCount, 4);
  });

  test('practice catalog rejects unsafe ids and invalid choice counts', () {
    final tooLong = List.filled(200, 'x').join();
    final restored = PracticeCatalogPreferences.fromJson({
      'favoriteActivityIds': ['/study?mode=mixed', '', tooLong],
      'hiddenActivityIds': ['/study?mode=mixed'],
      'launchByActivityId': {
        '/study?mode=meaning': {'choiceCount': 5},
        tooLong: {'choiceCount': 6},
      },
    });

    expect(restored.favoriteActivityIds, isEmpty);
    expect(restored.hiddenActivityIds, {'mixed-quiz'});
    expect(restored.launchFor('/study?mode=meaning').choiceCount, 4);
    expect(restored.launchByActivityId, hasLength(1));
  });
}
