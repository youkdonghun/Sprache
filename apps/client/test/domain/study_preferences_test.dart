import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  test('study preferences survive a JSON round trip', () {
    final preferences = StudyPreferences(
      dailyGoal: 150,
      sessionItemLimit: 15,
      newItemLimit: 17,
      reviewLimit: 55,
      sentenceRatio: 0.6,
      showReadingAids: false,
      ttsRate: 0.7,
      excludedItemIds: {'item-b', 'item-a'},
      favoriteItemIds: {'item-c', 'item-a'},
      completedMissionIds: {'ko-en:2', 'ko-ja:0'},
      preferredMode: StudyMode.listening,
      sessionPlan: StudySessionPlan(
        mode: StudyMode.production,
        deck: StudyDeckScope.unit,
        unitIndex: 3,
        difficulty: StudyDifficulty.weak,
        tags: {'여행', '동사'},
        levels: {'초급'},
        includeSentences: false,
        sentenceRatio: 0.2,
        itemLimit: 20,
        updatedAt: DateTime.utc(2026, 7, 28, 9),
      ),
    );

    final restored = StudyPreferences.fromJson(preferences.toJson());

    expect(restored.dailyGoal, 150);
    expect(restored.sessionItemLimit, 15);
    expect(restored.newItemLimit, 17);
    expect(restored.reviewLimit, 55);
    expect(restored.sentenceRatio, 0.6);
    expect(restored.showReadingAids, isFalse);
    expect(restored.ttsRate, 0.7);
    expect(restored.excludedItemIds, {'item-a', 'item-b'});
    expect(restored.favoriteItemIds, {'item-a', 'item-c'});
    expect(restored.completedMissionIds, {'ko-en:2', 'ko-ja:0'});
    expect(restored.isFavorite('item-c'), isTrue);
    expect(restored.hasCompletedMission('ko-ja', 0), isTrue);
    expect(restored.preferredMode, StudyMode.listening);
    expect(restored.sessionPlan.mode, StudyMode.production);
    expect(restored.sessionPlan.deck, StudyDeckScope.unit);
    expect(restored.sessionPlan.unitIndex, 3);
    expect(restored.sessionPlan.difficulty, StudyDifficulty.weak);
    expect(restored.sessionPlan.tags, {'여행', '동사'});
    expect(restored.sessionPlan.levels, {'초급'});
    expect(restored.sessionPlan.includeWords, isTrue);
    expect(restored.sessionPlan.includeSentences, isFalse);
    expect(restored.sessionPlan.itemLimit, 20);
    expect(restored.sessionPlan.updatedAt, DateTime.utc(2026, 7, 28, 9));
  });

  test('invalid persisted values are clamped to safe limits', () {
    final restored = StudyPreferences.fromJson({
      'dailyGoal': 9999,
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
        'includeWords': false,
        'includeSentences': false,
        'sentenceRatio': -4,
        'itemLimit': 100,
      },
    });

    expect(restored.dailyGoal, 500);
    expect(restored.sessionItemLimit, 30);
    expect(restored.newItemLimit, 0);
    expect(restored.reviewLimit, 1);
    expect(restored.sentenceRatio, 1);
    expect(restored.ttsRate, 0.2);
    expect(restored.preferredMode, StudyMode.mixed);
    expect(restored.sessionPlan.mode, StudyMode.mixed);
    expect(restored.sessionPlan.deck, StudyDeckScope.course);
    expect(restored.sessionPlan.unitIndex, 5);
    expect(restored.sessionPlan.difficulty, StudyDifficulty.all);
    expect(restored.sessionPlan.includeWords, isTrue);
    expect(restored.sessionPlan.includeSentences, isTrue);
    expect(restored.sessionPlan.sentenceRatio, 0);
    expect(restored.sessionPlan.itemLimit, 30);
  });
}
