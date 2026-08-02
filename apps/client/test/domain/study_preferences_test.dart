import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  test('legacy persisted preferences do not reopen onboarding', () {
    final restored = StudyPreferences.fromJson(const {
      'dailyGoal': 150,
      'sessionItemLimit': 15,
    });

    expect(restored.onboardingCompleted, isTrue);
    expect(restored.dailyGoal, 150);
    expect(restored.sessionItemLimit, 15);
  });

  test('an explicit incomplete onboarding flag is preserved', () {
    final restored = StudyPreferences.fromJson(const {
      'onboardingCompleted': false,
    });

    expect(restored.onboardingCompleted, isFalse);
  });

  test('study preferences survive a JSON round trip', () {
    final preferences = StudyPreferences(
      onboardingCompleted: true,
      dailyGoal: 150,
      dailyGoalsBySubject: const {'language:en': 100, 'language:ja': 200},
      dailyGoalChangedAtBySubject: {
        'language:en': DateTime.utc(2026, 7, 28, 7),
        'language:ja': DateTime.utc(2026, 7, 28, 8),
      },
      sessionItemLimit: 15,
      newItemLimit: 17,
      reviewLimit: 55,
      sentenceRatio: 0.6,
      showReadingAids: false,
      ttsRate: 0.7,
      experience: AppExperiencePreferences(
        colorMode: AppColorMode.dark,
        accentPalette: AppAccentPalette.ocean,
        density: AppDensity.compact,
        textScale: AppTextScale.large,
        reduceMotion: true,
        hapticsEnabled: true,
        updatedAt: DateTime.utc(2026, 7, 28, 9, 10),
      ),
      interaction: StudyInteractionPreferences(
        autoPlayQuestionAudio: true,
        preferOfflineVoice: true,
        audioRepeatCount: 2,
        showKoreanReading: false,
        showNativeReading: false,
        answerDirection: StudyAnswerDirection.meaningToLearning,
        choiceLayout: StudyChoiceLayout.grid,
        shuffleChoices: false,
        autoAdvanceCorrect: true,
        autoAdvanceDelayMs: 1200,
        updatedAt: DateTime.utc(2026, 7, 28, 9, 20),
      ),
      settingsUpdatedAt: DateTime.utc(2026, 7, 28, 9, 30),
      excludedItemIds: {'item-b', 'item-a'},
      excludedItemChangedAtById: {'item-a': DateTime.utc(2026, 7, 28, 6)},
      favoriteItemIds: {'item-c', 'item-a'},
      favoriteItemChangedAtById: {'item-c': DateTime.utc(2026, 7, 28, 7)},
      completedMissionIds: {'ko-en:2', 'ko-ja:0'},
      preferredMode: StudyMode.listening,
      sessionPlan: StudySessionPlan(
        planId: 'plan-current',
        subjectId: 'language:ja',
        mode: StudyMode.production,
        deck: StudyDeckScope.unit,
        unitIndex: 3,
        difficulty: StudyDifficulty.weak,
        queuePriority: StudyQueuePriority.newFirst,
        historyFilter: StudyHistoryFilter.wrongOnly,
        tags: {'여행', '동사'},
        levels: {'초급'},
        includeSentences: false,
        sentenceRatio: 0.2,
        itemLimit: 20,
        answerDirectionOverride: StudyAnswerDirection.meaningToLearning,
        gradingStrictness: StudyGradingStrictness.strict,
        choiceCount: 6,
        hintsEnabled: false,
        autoAdvanceOverride: true,
        soundEffectsOverride: true,
        largeControls: true,
        title: '여행 단어 퀴즈',
        scheduledAt: DateTime.utc(2026, 7, 30, 10),
        selectedItemIds: {'word-1', 'sentence-2'},
        updatedAt: DateTime.utc(2026, 7, 28, 9),
      ),
      savedSessionPlans: [
        StudySessionPlan(
          planId: 'plan-saved',
          subjectId: 'language:ja',
          title: '출근 전 복습',
          scheduledAt: DateTime.utc(2026, 7, 31, 22),
          updatedAt: DateTime.utc(2026, 7, 28, 8),
        ),
      ],
      savedSessionPlanTombstones: {
        'plan-deleted': DateTime.utc(2026, 7, 28, 8, 30),
      },
      activeSubjectId: 'language:ja',
      activeSubjectChangedAt: DateTime.utc(2026, 7, 28, 9),
      learningGroups: [
        LearningGroupDefinition(
          subjectId: 'language:ja',
          name: '여행 준비',
          description: '공항과 숙소에서 쓸 표현',
          colorKey: 'purple',
          pinned: true,
          sortOrder: 2,
          createdAt: DateTime.utc(2026, 7, 28, 7),
          updatedAt: DateTime.utc(2026, 7, 28, 9),
        ),
      ],
      learningGroupTombstones: {
        'language:ja\u001F이전 그룹': DateTime.utc(2026, 7, 28, 8),
      },
    );

    final restored = StudyPreferences.fromJson(preferences.toJson());

    expect(restored.onboardingCompleted, isTrue);
    expect(restored.dailyGoal, 150);
    expect(restored.dailyGoalFor('language:en'), 100);
    expect(restored.dailyGoalFor('language:ja'), 200);
    expect(restored.dailyGoalFor('language:de'), 150);
    expect(
      restored.dailyGoalChangedAtBySubject['language:en'],
      DateTime.utc(2026, 7, 28, 7),
    );
    expect(restored.sessionItemLimit, 15);
    expect(restored.newItemLimit, 17);
    expect(restored.reviewLimit, 55);
    expect(restored.sentenceRatio, 0.6);
    expect(restored.showReadingAids, isFalse);
    expect(restored.ttsRate, 0.7);
    expect(restored.experience.colorMode, AppColorMode.dark);
    expect(restored.experience.accentPalette, AppAccentPalette.ocean);
    expect(restored.experience.density, AppDensity.compact);
    expect(restored.experience.textScale, AppTextScale.large);
    expect(restored.experience.reduceMotion, isTrue);
    expect(restored.experience.hapticsEnabled, isTrue);
    expect(restored.experience.updatedAt, DateTime.utc(2026, 7, 28, 9, 10));
    expect(restored.interaction.autoPlayQuestionAudio, isTrue);
    expect(restored.interaction.audioRepeatCount, 2);
    expect(restored.interaction.showKoreanReading, isFalse);
    expect(
      restored.interaction.answerDirection,
      StudyAnswerDirection.meaningToLearning,
    );
    expect(restored.sessionPlan.choiceCount, 6);
    expect(restored.sessionPlan.hintsEnabled, isFalse);
    expect(restored.sessionPlan.autoAdvanceOverride, isTrue);
    expect(restored.sessionPlan.soundEffectsOverride, isTrue);
    expect(restored.sessionPlan.largeControls, isTrue);
    expect(
      restored.sessionPlan.gradingStrictness,
      StudyGradingStrictness.strict,
    );
    expect(restored.interaction.choiceLayout, StudyChoiceLayout.grid);
    expect(restored.interaction.shuffleChoices, isFalse);
    expect(restored.interaction.autoAdvanceCorrect, isTrue);
    expect(restored.interaction.autoAdvanceDelayMs, 1200);
    expect(restored.interaction.updatedAt, DateTime.utc(2026, 7, 28, 9, 20));
    expect(restored.settingsUpdatedAt, DateTime.utc(2026, 7, 28, 9, 30));
    expect(restored.excludedItemIds, {'item-a', 'item-b'});
    expect(
      restored.excludedItemChangedAtById['item-a'],
      DateTime.utc(2026, 7, 28, 6),
    );
    expect(restored.favoriteItemIds, {'item-a', 'item-c'});
    expect(
      restored.favoriteItemChangedAtById['item-c'],
      DateTime.utc(2026, 7, 28, 7),
    );
    expect(restored.completedMissionIds, {'ko-en:2', 'ko-ja:0'});
    expect(restored.isFavorite('item-c'), isTrue);
    expect(restored.hasCompletedMission('ko-ja', 0), isTrue);
    expect(restored.preferredMode, StudyMode.listening);
    expect(restored.sessionPlan.planId, 'plan-current');
    expect(restored.sessionPlan.subjectId, 'language:ja');
    expect(restored.sessionPlan.mode, StudyMode.production);
    expect(restored.sessionPlan.deck, StudyDeckScope.unit);
    expect(restored.sessionPlan.unitIndex, 3);
    expect(restored.sessionPlan.difficulty, StudyDifficulty.weak);
    expect(restored.sessionPlan.queuePriority, StudyQueuePriority.newFirst);
    expect(restored.sessionPlan.historyFilter, StudyHistoryFilter.wrongOnly);
    expect(restored.sessionPlan.tags, {'여행', '동사'});
    expect(restored.sessionPlan.levels, {'초급'});
    expect(restored.sessionPlan.includeWords, isTrue);
    expect(restored.sessionPlan.includeSentences, isFalse);
    expect(restored.sessionPlan.itemLimit, 20);
    expect(restored.sessionPlan.title, '여행 단어 퀴즈');
    expect(restored.sessionPlan.scheduledAt, DateTime.utc(2026, 7, 30, 10));
    expect(restored.sessionPlan.selectedItemIds, {'word-1', 'sentence-2'});
    expect(restored.sessionPlan.updatedAt, DateTime.utc(2026, 7, 28, 9));
    expect(restored.savedSessionPlans.single.planId, 'plan-saved');
    expect(restored.savedSessionPlans.single.subjectId, 'language:ja');
    expect(restored.savedSessionPlans.single.title, '출근 전 복습');
    expect(
      restored.savedSessionPlanTombstones['plan-deleted'],
      DateTime.utc(2026, 7, 28, 8, 30),
    );
    expect(restored.activeSubjectId, 'language:ja');
    expect(restored.activeSubjectChangedAt, DateTime.utc(2026, 7, 28, 9));
    expect(restored.learningGroups.single.name, '여행 준비');
    expect(restored.learningGroups.single.description, '공항과 숙소에서 쓸 표현');
    expect(restored.learningGroups.single.colorKey, 'purple');
    expect(restored.learningGroups.single.pinned, isTrue);
    expect(restored.learningGroups.single.sortOrder, 2);
    expect(
      restored.learningGroupTombstones['language:ja\u001F이전 그룹'],
      DateTime.utc(2026, 7, 28, 8),
    );
  });

  test('legacy schedules inherit the persisted active study subject', () {
    final restored = StudyPreferences.fromJson({
      'activeSubjectId': 'language:de',
      'sessionPlan': const StudySessionPlan(planId: 'legacy-current').toJson()
        ..remove('subjectId'),
      'savedSessionPlans': [
        const StudySessionPlan(planId: 'legacy-saved', title: '이전 일정').toJson()
          ..remove('subjectId'),
      ],
    });

    expect(restored.sessionPlan.subjectId, 'language:de');
    expect(restored.savedSessionPlans.single.subjectId, 'language:de');
  });

  test('legacy reading toggle migrates to both reading controls', () {
    final hidden = StudyPreferences.fromJson({'showReadingAids': false});
    final visible = StudyPreferences.fromJson({'showReadingAids': true});

    expect(hidden.interaction.showKoreanReading, isFalse);
    expect(hidden.interaction.showNativeReading, isFalse);
    expect(visible.interaction.showKoreanReading, isTrue);
    expect(visible.interaction.showNativeReading, isTrue);
  });

  test('invalid persisted values are clamped to safe limits', () {
    final restored = StudyPreferences.fromJson({
      'dailyGoal': 9999,
      'dailyGoalsBySubject': {
        'language:en': 5,
        'language:ja': 9999,
        'bad subject': 200,
      },
      'sessionItemLimit': 999,
      'newItemLimit': -10,
      'reviewLimit': 0,
      'sentenceRatio': 3,
      'ttsRate': 0.01,
      'preferredMode': 'not-a-mode',
      'sessionPlan': {
        'mode': 'not-a-mode',
        'deck': 'not-a-deck',
        'unitIndex': 99,
        'difficulty': 'not-a-difficulty',
        'queuePriority': 'not-a-priority',
        'historyFilter': 'not-a-history-filter',
        'includeWords': false,
        'includeSentences': false,
        'sentenceRatio': -4,
        'itemLimit': 101,
      },
    });

    expect(restored.dailyGoal, 500);
    expect(restored.dailyGoalFor('language:en'), 20);
    expect(restored.dailyGoalFor('language:ja'), 500);
    expect(restored.dailyGoalsBySubject, isNot(contains('bad subject')));
    expect(restored.sessionItemLimit, 100);
    expect(restored.newItemLimit, 0);
    expect(restored.reviewLimit, 1);
    expect(restored.sentenceRatio, 1);
    expect(restored.ttsRate, 0.2);
    expect(restored.preferredMode, StudyMode.mixed);
    expect(restored.sessionPlan.mode, StudyMode.mixed);
    expect(restored.sessionPlan.deck, StudyDeckScope.course);
    expect(restored.sessionPlan.unitIndex, 5);
    expect(restored.sessionPlan.difficulty, StudyDifficulty.all);
    expect(restored.sessionPlan.queuePriority, StudyQueuePriority.dueFirst);
    expect(restored.sessionPlan.historyFilter, StudyHistoryFilter.all);
    expect(restored.sessionPlan.includeWords, isTrue);
    expect(restored.sessionPlan.includeSentences, isTrue);
    expect(restored.sessionPlan.sentenceRatio, 0);
    expect(restored.sessionPlan.itemLimit, 100);
  });

  test('updates one subject goal without changing another subject', () {
    const preferences = StudyPreferences(dailyGoal: 100);

    final japanese = preferences.withDailyGoalForSubject(
      'language:ja',
      200,
      changedAt: DateTime.utc(2026, 7, 28, 8),
    );
    final english = japanese.withDailyGoalForSubject(
      'language:en',
      50,
      changedAt: DateTime.utc(2026, 7, 28, 9),
    );

    expect(english.dailyGoalFor('language:ja'), 200);
    expect(english.dailyGoalFor('language:en'), 50);
    expect(english.dailyGoalFor('language:de'), 100);
    expect(english.dailyGoalChangedAtBySubject, {
      'language:ja': DateTime.utc(2026, 7, 28, 8),
      'language:en': DateTime.utc(2026, 7, 28, 9),
    });
  });
}
