import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  test('Drift preserves completed session lineage metadata', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftStudyStore(database);
    final startedAt = DateTime.utc(2026, 7, 28, 9);
    final active = ActiveStudySession.started(
      sessionId: 'root',
      courseId: 'ko-en',
      mode: StudyMode.mixed,
      unitIndex: null,
      itemIds: const ['a', 'b'],
      startedAt: startedAt,
    )
        .pause(startedAt.add(const Duration(minutes: 1)))
        .resume(startedAt.add(const Duration(minutes: 2)))
        .derive(
          newSessionId: 'branch',
          nextOrigin: StudySessionOrigin.wrongAnswers,
          selectedItemIds: const ['a'],
          startedAt: startedAt.add(const Duration(minutes: 3)),
        );
    final summary = StudySessionSummary(
      sessionId: active.sessionId,
      courseId: active.courseId,
      startedAt: active.startedAt,
      endedAt: active.startedAt.add(const Duration(minutes: 2)),
      correctCount: 1,
      wrongCount: 0,
      earnedXp: 10,
      origin: active.origin,
      rootSessionId: active.lineageRootId,
      parentSessionId: active.parentSessionId,
      generation: active.generation,
      pauseCount: active.pauseCount,
      resumeCount: active.resumeCount,
      journey: active.journey,
    );

    try {
      await store.saveStudySession(summary);
      final restored = (await store.loadRecentSessions()).single;

      expect(restored.origin, StudySessionOrigin.wrongAnswers);
      expect(restored.rootSessionId, 'root');
      expect(restored.parentSessionId, 'root');
      expect(restored.generation, 1);
      expect(restored.pauseCount, 1);
      expect(restored.resumeCount, 1);
      expect(restored.journey, hasLength(4));
    } finally {
      await database.close();
    }
  });

  test('schema v1 database migrates and keeps legacy session rows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-session-migration-',
    );
    final file = File('${directory.path}/legacy.sqlite');
    final startedAt = DateTime.utc(2026, 7, 27, 8);

    try {
      final currentDatabase = AppDatabase(NativeDatabase(file));
      final currentStore = DriftStudyStore(currentDatabase);
      await currentStore.saveStudySession(
        StudySessionSummary(
          sessionId: 'legacy-session',
          courseId: 'ko-en',
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 3)),
          correctCount: 2,
          wrongCount: 1,
          earnedXp: 25,
        ),
      );
      await currentDatabase.close();

      final migratedDatabase = AppDatabase(
        NativeDatabase(
          file,
          setup: (database) {
            database.execute(
              'ALTER TABLE study_sessions DROP COLUMN metadata_json',
            );
            database.execute('PRAGMA user_version = 1');
          },
        ),
      );
      final migratedStore = DriftStudyStore(migratedDatabase);
      final restored = (await migratedStore.loadRecentSessions()).single;

      expect(migratedDatabase.schemaVersion, 2);
      expect(restored.sessionId, 'legacy-session');
      expect(restored.correctCount, 2);
      expect(restored.origin, StudySessionOrigin.fresh);
      await migratedDatabase.close();
    } finally {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
