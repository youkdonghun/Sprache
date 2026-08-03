import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/backup_archive.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('validated backup merges without faking a Drive connection', () async {
    final source = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    source.selectLanguage(LanguageTag.japanese);
    await source.upsertCustomItem(
      LearningItem(
        id: 'source-item',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.japanese,
        text: '旅',
        translations: const ['여행'],
        acceptedAnswers: const ['여행'],
        tags: [learningGroupTag('출장 일본어')],
      ),
    );
    await source.finishSession(
      StudySessionSummary(
        sessionId: 'source-session',
        courseId: 'ko-ja',
        startedAt: DateTime.utc(2026, 7, 28, 10),
        endedAt: DateTime.utc(2026, 7, 28, 10, 6),
        correctCount: 5,
        wrongCount: 1,
        earnedXp: 55,
      ),
    );
    final archive = const BackupArchiveCodec().validate(source.exportArchive());

    final targetStore = MemoryStudyStore();
    final target = AppController(targetStore);
    await Future<void>.delayed(Duration.zero);
    await target.upsertCustomItem(
      const LearningItem(
        id: 'local-item',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'local',
        translations: ['로컬'],
        acceptedAnswers: ['로컬'],
      ),
    );

    final result = await target.restoreBackup(archive);

    expect(
      target.state.customItems.map((item) => item.id),
      containsAll(['local-item', 'source-item']),
    );
    expect(target.state.selectedLanguage, LanguageTag.japanese);
    expect(target.state.driveConnected, isFalse);
    expect(targetStore.savedSessions.single.sessionId, 'source-session');
    expect(result.customItemCount, 2);
    expect(result.restoredSessionCount, 1);
    expect(targetStore.pendingSnapshotSync, isNotNull);
    source.dispose();
    target.dispose();
  });

  test(
    'preview reports deltas and category selection preserves local data',
    () async {
      final source = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      source.selectLanguage(LanguageTag.japanese);
      await source.upsertCustomItem(
        const LearningItem(
          id: 'incoming-item',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.japanese,
          text: '安全',
          translations: ['안전'],
          acceptedAnswers: ['안전'],
        ),
      );
      await source.finishSession(
        StudySessionSummary(
          sessionId: 'incoming-session',
          courseId: 'ko-ja',
          startedAt: DateTime.utc(2026, 8, 2, 10),
          endedAt: DateTime.utc(2026, 8, 2, 10, 5),
          correctCount: 4,
          wrongCount: 1,
          earnedXp: 40,
        ),
      );
      final archive = const BackupArchiveCodec().validate(
        source.exportArchive(),
      );

      final targetStore = MemoryStudyStore();
      final target = AppController(targetStore);
      await Future<void>.delayed(Duration.zero);
      await target.upsertCustomItem(
        const LearningItem(
          id: 'local-item',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'local',
          translations: ['로컬'],
          acceptedAnswers: ['로컬'],
        ),
      );
      const contentOnly = BackupRestoreSelection(
        progress: false,
        sessions: false,
        settings: false,
      );

      final preview = target.previewBackupRestore(
        archive,
        selection: contentOnly,
      );
      expect(
        preview.byCategory[BackupRestoreCategory.content]?.added,
        greaterThanOrEqualTo(1),
      );
      expect(preview.byCategory[BackupRestoreCategory.sessions]?.changed, 0);

      final result = await target.restoreBackup(
        archive,
        selection: contentOnly,
      );

      expect(
        target.state.customItems.map((item) => item.id),
        containsAll(['local-item', 'incoming-item']),
      );
      expect(target.state.selectedLanguage, LanguageTag.english);
      expect(targetStore.savedSessions, isEmpty);
      expect(result.restoredSessionCount, 0);
      source.dispose();
      target.dispose();
    },
  );
}
