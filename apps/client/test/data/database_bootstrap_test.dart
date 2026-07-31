import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/database/database_bootstrap.dart';

void main() {
  test('opens and initializes a missing database normally', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-database-bootstrap-new-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}sprache.sqlite',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = DatabaseBootstrapService(
      databasePathResolver: () async => file.path,
      openDatabase: () => _openDatabase(file),
    );

    final result = await service.open();

    expect(result, isA<DatabaseReady>());
    final ready = result as DatabaseReady;
    expect(await file.exists(), isTrue);
    expect(
      await ready.database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      AppDatabase.currentSchemaVersion,
    );
    await ready.database.close();
  });

  test('newer schema is never opened or downgraded', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-database-bootstrap-newer-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}sprache.sqlite',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = await _openDatabase(file);
    await database.close();
    await _writeUserVersion(file, AppDatabase.currentSchemaVersion + 5);
    final originalHash = sha256.convert(await file.readAsBytes()).toString();
    var opened = false;
    final service = DatabaseBootstrapService(
      databasePathResolver: () async => file.path,
      openDatabase: () async {
        opened = true;
        throw StateError('must not open a newer database');
      },
      clock: () => DateTime.utc(2026, 7, 29, 3),
    );

    final result = await service.open();

    expect(opened, isFalse);
    expect(result, isA<DatabaseRecoveryRequired>());
    final diagnostic = (result as DatabaseRecoveryRequired).diagnostic;
    expect(diagnostic.code, DatabaseRecoveryCode.newerSchema);
    expect(
      diagnostic.detectedSchemaVersion,
      AppDatabase.currentSchemaVersion + 5,
    );
    expect(diagnostic.hasPreservedDatabase, isTrue);
    expect(diagnostic.preservedFiles.single.sha256, originalHash);
    expect(sha256.convert(await file.readAsBytes()).toString(), originalHash);
  });

  test('invalid SQLite header enters recovery without opening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-database-bootstrap-invalid-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}sprache.sqlite',
    );
    addTearDown(() => directory.delete(recursive: true));
    await file.writeAsBytes(List<int>.generate(160, (index) => index % 251));
    var opened = false;
    final service = DatabaseBootstrapService(
      databasePathResolver: () async => file.path,
      openDatabase: () async {
        opened = true;
        throw StateError('must not open invalid bytes');
      },
    );

    final result = await service.open();

    expect(opened, isFalse);
    final diagnostic = (result as DatabaseRecoveryRequired).diagnostic;
    expect(diagnostic.code, DatabaseRecoveryCode.invalidDatabase);
    expect(diagnostic.preservedFiles, hasLength(1));
    expect(await file.readAsBytes(), List<int>.generate(160, (i) => i % 251));
  });

  test(
    'migration failure preserves the pre-migration database and rolls back',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sprache-database-bootstrap-migration-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}sprache.sqlite',
      );
      addTearDown(() => directory.delete(recursive: true));
      final current = await _openDatabase(file);
      await current.close();
      await _writeUserVersion(file, 1);
      final originalHash = sha256.convert(await file.readAsBytes()).toString();
      final service = DatabaseBootstrapService(
        databasePathResolver: () async => file.path,
        openDatabase: () => _openDatabase(file),
        clock: () => DateTime.utc(2026, 7, 29, 4),
      );

      final result = await service.open();

      final diagnostic = (result as DatabaseRecoveryRequired).diagnostic;
      expect(diagnostic.code, DatabaseRecoveryCode.migrationFailed);
      expect(diagnostic.detectedSchemaVersion, 1);
      expect(diagnostic.hasPreservedDatabase, isTrue);
      expect(diagnostic.preservedFiles.single.sha256, originalHash);
      expect(diagnostic.summary, contains('일부 변경도 적용하지 않았습니다'));
    },
  );

  test(
    'recovery archive contains checksummed DB and a safe manifest',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sprache-database-bootstrap-archive-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}sprache.sqlite',
      );
      addTearDown(() => directory.delete(recursive: true));
      await file.writeAsBytes(List<int>.filled(128, 7));
      final service = DatabaseBootstrapService(
        databasePathResolver: () async => file.path,
        openDatabase: () async => throw StateError('not reached'),
        clock: () => DateTime.utc(2026, 7, 29, 5),
      );
      final result = await service.open() as DatabaseRecoveryRequired;

      final bytes = await service.createRecoveryArchive(result.diagnostic);
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);

      expect(
        archive.files.map((file) => file.name),
        containsAll(['sprache.sqlite', 'recovery-manifest.json']),
      );
      final manifest = archive.files.singleWhere(
        (file) => file.name == 'recovery-manifest.json',
      );
      final text = String.fromCharCodes(manifest.content as List<int>);
      expect(text, contains('sprache-database-recovery-v1'));
      expect(text, contains(DatabaseRecoveryCode.invalidDatabase.stableCode));
      expect(text, isNot(contains(directory.path)));
    },
  );
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
