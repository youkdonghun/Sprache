import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/backup_archive.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('exported archive is fully validated before restore', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    const item = LearningItem(
      id: 'backup-item',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'backup',
      translations: ['백업'],
      acceptedAnswers: ['백업'],
    );
    await controller.upsertCustomItem(item);
    await controller.finishSession(
      StudySessionSummary(
        sessionId: 'backup-session',
        courseId: 'subject:general:baseball',
        startedAt: DateTime.utc(2026, 7, 28, 9),
        endedAt: DateTime.utc(2026, 7, 28, 9, 5),
        correctCount: 4,
        wrongCount: 1,
        earnedXp: 45,
      ),
    );

    final source = jsonEncode(controller.exportArchive());
    final archive = const BackupArchiveCodec().decode(source);

    expect(archive.selectedLanguage, LanguageTag.english);
    expect(archive.customItemCount, 1);
    expect(archive.sessions.single.sessionId, 'backup-session');
    controller.dispose();
  });

  test('unsupported or malformed archives report a precise safe path', () {
    expect(
      () => const BackupArchiveCodec().decode(
        jsonEncode({
          'schemaVersion': 2,
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'profile': <String, Object?>{},
          'settings': <String, Object?>{},
          'progress': <Object?>[],
          'customItems': <Object?>[],
          'customItemTombstones': <Object?>[],
          'activeStudy': null,
          'exportedAt': DateTime.utc(2026).toIso8601String(),
          'sessions': <Object?>[],
        }),
      ),
      throwsA(
        isA<BackupArchiveException>().having(
          (error) => error.path,
          'path',
          r'$.schemaVersion',
        ),
      ),
    );

    expect(
      () => const BackupArchiveCodec().decode('{"schemaVersion":1}'),
      throwsA(
        isA<BackupArchiveException>().having(
          (error) => error.path,
          'path',
          r'$',
        ),
      ),
    );
  });
}
