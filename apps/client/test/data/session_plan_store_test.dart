import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  test('Drift preserves the complete custom session plan', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftStudyStore(database);
    final updatedAt = DateTime.utc(2026, 7, 28, 10);
    final preferences = StudyPreferences(
      sessionPlan: StudySessionPlan(
        mode: StudyMode.sentenceOrder,
        deck: StudyDeckScope.unit,
        unitIndex: 2,
        difficulty: StudyDifficulty.learning,
        tags: const {'시간', '문장'},
        levels: const {'초급'},
        includeWords: false,
        sentenceRatio: 1,
        itemLimit: 15,
        updatedAt: updatedAt,
      ),
    );

    try {
      await store.savePreferences(preferences);
      final restored = (await store.loadPreferences()).sessionPlan;

      expect(restored.mode, StudyMode.sentenceOrder);
      expect(restored.deck, StudyDeckScope.unit);
      expect(restored.unitIndex, 2);
      expect(restored.difficulty, StudyDifficulty.learning);
      expect(restored.tags, {'시간', '문장'});
      expect(restored.levels, {'초급'});
      expect(restored.includeWords, isFalse);
      expect(restored.includeSentences, isTrue);
      expect(restored.sentenceRatio, 1);
      expect(restored.itemLimit, 15);
      expect(restored.updatedAt, updatedAt);
    } finally {
      await database.close();
    }
  });
}
