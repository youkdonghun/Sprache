import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  test('Drift preserves account and daily per-device XP ledgers', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftStudyStore(database);
    final profile = StoredProfile(
      selectedLanguage: LanguageTag.english,
      totalXp: 300,
      replicaId: 'replica-windows',
      xpByReplica: const {'replica-windows': 180, 'replica-android': 120},
      streakDays: 4,
      dailyXp: 30,
      dailyXpByCourse: const {'ko-en': 20, 'ko-ja': 10},
      dailyXpByCourseAndReplica: const {
        'ko-en': {'replica-windows': 10, 'replica-android': 10},
        'ko-ja': {'replica-android': 10},
      },
      badges: const {'첫걸음'},
      driveConnected: false,
      progress: const {},
      lastStudyDate: DateTime.utc(2026, 7, 29),
    );

    try {
      await store.saveProfile(profile);
      final restored = await store.loadProfile();

      expect(restored.replicaId, 'replica-windows');
      expect(restored.xpByReplica, profile.xpByReplica);
      expect(
        restored.dailyXpByCourseAndReplica,
        profile.dailyXpByCourseAndReplica,
      );
      expect(restored.dailyXpByCourse, profile.dailyXpByCourse);
      expect(restored.totalXp, 300);
      expect(restored.dailyXp, 30);
    } finally {
      await database.close();
    }
  });
}
