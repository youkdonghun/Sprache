import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/database/database_bootstrap.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_history.dart';

void main() {
  test(
    '1.30 database upgrades to 1.31 without losing real study data',
    () async {
      final fixture = await _Legacy130Fixture.create();
      addTearDown(fixture.dispose);
      final originalHash = sha256.convert(await fixture.file.readAsBytes());
      final service = DatabaseBootstrapService(
        databasePathResolver: () async => fixture.file.path,
        openDatabase: () => _openDatabase(fixture.file),
        clock: () => DateTime.utc(2026, 8, 3, 4),
      );

      final result = await service.open();

      expect(result, isA<DatabaseReady>());
      final database = (result as DatabaseReady).database;
      final store = DriftStudyStore(database);
      final preferences = await store.loadPreferences();
      final profile = await store.loadProfile();
      final items = await store.loadCustomItems();
      final sessions = await store.loadRecentSessions();
      expect(preferences.onboardingCompleted, isTrue);
      expect(preferences.showReadingAids, isFalse);
      expect(profile.totalXp, 1310);
      expect(profile.progress['legacy-word']?.correctCount, 7);
      expect(items.single.id, 'legacy-word');
      expect(items.single.text, 'upgrade');
      expect(sessions.single.sessionId, 'legacy-session');
      expect(sessions.single.correctCount, 7);
      expect(sessions.single.origin.name, 'fresh');
      expect(
        await database
            .customSelect('PRAGMA user_version')
            .map((row) => row.read<int>('user_version'))
            .getSingle(),
        AppDatabase.currentSchemaVersion,
      );
      await database.close();

      final recoveryRoot = Directory(
        '${fixture.directory.path}${Platform.pathSeparator}sprache-recovery',
      );
      final preserved = await recoveryRoot
          .list(recursive: true)
          .where(
            (entry) => entry is File && entry.path.endsWith('sprache.sqlite'),
          )
          .cast<File>()
          .toList();
      expect(preserved, hasLength(1));
      expect(
        sha256.convert(await preserved.single.readAsBytes()),
        originalHash,
      );
    },
  );

  test(
    'corrupt 1.30 bytes enter recovery and never replace the source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sprache-130-corrupt-e2e-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}sprache.sqlite',
      );
      final corruptBytes = List<int>.generate(
        512,
        (index) => (index * 31) % 251,
      );
      await file.writeAsBytes(corruptBytes, flush: true);
      final originalHash = sha256.convert(corruptBytes);
      var opened = false;
      final service = DatabaseBootstrapService(
        databasePathResolver: () async => file.path,
        openDatabase: () async {
          opened = true;
          throw StateError('corrupt database must not be opened');
        },
        clock: () => DateTime.utc(2026, 8, 3, 5),
      );

      final result = await service.open() as DatabaseRecoveryRequired;

      expect(opened, isFalse);
      expect(result.diagnostic.code, DatabaseRecoveryCode.invalidDatabase);
      expect(result.diagnostic.hasPreservedDatabase, isTrue);
      expect(sha256.convert(await file.readAsBytes()), originalHash);
      expect(result.diagnostic.preservedFiles.single.sha256, '$originalHash');
    },
  );

  test('future database schema is preserved and blocked before open', () async {
    final fixture = await _Legacy130Fixture.create();
    addTearDown(fixture.dispose);
    await _writeUserVersion(
      fixture.file,
      AppDatabase.currentSchemaVersion + 100,
    );
    final originalHash = sha256.convert(await fixture.file.readAsBytes());
    var opened = false;
    final service = DatabaseBootstrapService(
      databasePathResolver: () async => fixture.file.path,
      openDatabase: () async {
        opened = true;
        throw StateError('future schema must not be opened');
      },
      clock: () => DateTime.utc(2026, 8, 3, 6),
    );

    final result = await service.open() as DatabaseRecoveryRequired;

    expect(opened, isFalse);
    expect(result.diagnostic.code, DatabaseRecoveryCode.newerSchema);
    expect(
      result.diagnostic.detectedSchemaVersion,
      AppDatabase.currentSchemaVersion + 100,
    );
    expect(result.diagnostic.preservedFiles.single.sha256, '$originalHash');
    expect(sha256.convert(await fixture.file.readAsBytes()), originalHash);
  });
}

class _Legacy130Fixture {
  const _Legacy130Fixture(this.directory, this.file);

  final Directory directory;
  final File file;

  static Future<_Legacy130Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-130-upgrade-e2e-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}sprache.sqlite',
    );
    final database = await _openDatabase(file);
    final store = DriftStudyStore(database);
    final studiedAt = DateTime.utc(2026, 7, 30, 9);
    const item = LearningItem(
      id: 'legacy-word',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'upgrade',
      translations: ['업그레이드'],
      acceptedAnswers: ['업그레이드'],
      source: ContentSource.userCreated,
    );
    final progress = ProgressRecord(
      itemId: item.id,
      status: LearningStatus.review,
      correctCount: 7,
      wrongCount: 2,
      nextReviewAt: studiedAt.add(const Duration(days: 2)),
      lastStudiedAt: studiedAt,
    );
    await store.saveCustomItems(const [item]);
    await store.saveProfile(
      StoredProfile(
        selectedLanguage: LanguageTag.english,
        totalXp: 1310,
        streakDays: 13,
        dailyXp: 10,
        badges: const {'legacy-learner'},
        driveConnected: false,
        progress: {item.id: progress},
        replicaId: 'legacy-device',
      ),
    );
    await store.saveStudySession(
      StudySessionSummary(
        sessionId: 'legacy-session',
        courseId: LanguageTag.english.courseId,
        startedAt: studiedAt,
        endedAt: studiedAt.add(const Duration(minutes: 13)),
        correctCount: 7,
        wrongCount: 2,
        earnedXp: 70,
      ),
    );
    await database.customStatement(
      'INSERT OR REPLACE INTO app_settings '
      '("key", value_json, updated_at) VALUES (?, ?, ?)',
      [
        'study_preferences',
        jsonEncode({
          'onboardingCompleted': true,
          'showReadingAids': false,
          'activeSubjectId': 'language:en',
        }),
        studiedAt.millisecondsSinceEpoch ~/ 1000,
      ],
    );
    await database.customStatement(
      'ALTER TABLE study_sessions DROP COLUMN metadata_json',
    );
    await database.customStatement('PRAGMA user_version = 1');
    await database.close();
    return _Legacy130Fixture(directory, file);
  }

  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<AppDatabase> _openDatabase(File file) async {
  final database = AppDatabase(NativeDatabase(file));
  try {
    await database.customSelect('SELECT 1').get();
    return database;
  } catch (_) {
    await database.close();
    rethrow;
  }
}

Future<void> _writeUserVersion(File file, int version) async {
  final bytes = await file.readAsBytes();
  bytes.setRange(60, 64, [
    (version >> 24) & 0xff,
    (version >> 16) & 0xff,
    (version >> 8) & 0xff,
    version & 0xff,
  ]);
  await file.writeAsBytes(bytes, flush: true);
}
