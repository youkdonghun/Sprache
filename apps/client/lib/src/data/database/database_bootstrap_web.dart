import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'app_database.dart';

enum DatabaseRecoveryCode {
  newerSchema,
  invalidDatabase,
  migrationBackupFailed,
  migrationFailed,
  databaseOpenFailed,
  databaseLocationUnavailable,
}

extension DatabaseRecoveryCodeLabel on DatabaseRecoveryCode {
  String get stableCode => switch (this) {
    DatabaseRecoveryCode.newerSchema => 'database_newer_schema',
    DatabaseRecoveryCode.invalidDatabase => 'database_invalid_header',
    DatabaseRecoveryCode.migrationBackupFailed =>
      'database_migration_backup_failed',
    DatabaseRecoveryCode.migrationFailed => 'database_migration_failed',
    DatabaseRecoveryCode.databaseOpenFailed => 'database_open_failed',
    DatabaseRecoveryCode.databaseLocationUnavailable =>
      'database_location_unavailable',
  };

  String get title => switch (this) {
    DatabaseRecoveryCode.newerSchema => '더 새로운 앱에서 만든 데이터입니다',
    DatabaseRecoveryCode.invalidDatabase => '학습 데이터 파일을 확인해야 합니다',
    DatabaseRecoveryCode.migrationBackupFailed => '안전 사본을 만들지 못했습니다',
    DatabaseRecoveryCode.migrationFailed => '업그레이드를 마치지 못했습니다',
    DatabaseRecoveryCode.databaseOpenFailed => '브라우저 학습 데이터를 열지 못했습니다',
    DatabaseRecoveryCode.databaseLocationUnavailable =>
      '브라우저 저장 공간에 접근하지 못했습니다',
  };
}

class PreservedDatabaseFile {
  const PreservedDatabaseFile({
    required this.path,
    required this.archiveName,
    required this.byteLength,
    required this.sha256,
  });

  final String path;
  final String archiveName;
  final int byteLength;
  final String sha256;
}

class DatabaseRecoveryDiagnostic {
  const DatabaseRecoveryDiagnostic({
    required this.code,
    required this.summary,
    required this.expectedSchemaVersion,
    required this.detectedSchemaVersion,
    required this.databaseByteLength,
    required this.databaseModifiedAt,
    required this.preservedFiles,
    required this.preservedAt,
    required this.technicalSummary,
  });

  final DatabaseRecoveryCode code;
  final String summary;
  final int expectedSchemaVersion;
  final int? detectedSchemaVersion;
  final int? databaseByteLength;
  final DateTime? databaseModifiedAt;
  final List<PreservedDatabaseFile> preservedFiles;
  final DateTime preservedAt;
  final String technicalSummary;

  bool get hasPreservedDatabase => preservedFiles.isNotEmpty;

  String get clipboardText => [
    'Sprache browser database recovery',
    'code: ${code.stableCode}',
    'schema: ${detectedSchemaVersion ?? 'unknown'} / expected: $expectedSchemaVersion',
    'time: ${preservedAt.toUtc().toIso8601String()}',
    'technical: $technicalSummary',
  ].join('\n');
}

sealed class DatabaseBootstrapResult {
  const DatabaseBootstrapResult();
}

class DatabaseReady extends DatabaseBootstrapResult {
  const DatabaseReady(this.database);

  final AppDatabase database;
}

class DatabaseRecoveryRequired extends DatabaseBootstrapResult {
  const DatabaseRecoveryRequired(this.diagnostic);

  final DatabaseRecoveryDiagnostic diagnostic;
}

abstract interface class DatabaseBootstrapper {
  Future<DatabaseBootstrapResult> open();

  Future<Uint8List> createRecoveryArchive(
    DatabaseRecoveryDiagnostic diagnostic,
  );
}

class DatabaseBootstrapService implements DatabaseBootstrapper {
  const DatabaseBootstrapService();

  @override
  Future<DatabaseBootstrapResult> open() async {
    final database = AppDatabase.defaults();
    try {
      await database.customSelect('PRAGMA quick_check').get();
      return DatabaseReady(database);
    } catch (error) {
      await database.close();
      return DatabaseRecoveryRequired(
        DatabaseRecoveryDiagnostic(
          code: DatabaseRecoveryCode.databaseOpenFailed,
          summary: '브라우저 저장 공간을 열지 못해 기존 자료를 변경하지 않았습니다.',
          expectedSchemaVersion: AppDatabase.currentSchemaVersion,
          detectedSchemaVersion: null,
          databaseByteLength: null,
          databaseModifiedAt: null,
          preservedFiles: const [],
          preservedAt: DateTime.now().toUtc(),
          technicalSummary: error.runtimeType.toString(),
        ),
      );
    }
  }

  @override
  Future<Uint8List> createRecoveryArchive(
    DatabaseRecoveryDiagnostic diagnostic,
  ) async {
    final content = utf8.encode(diagnostic.clipboardText);
    final archive = Archive()
      ..addFile(ArchiveFile('browser-recovery.txt', content.length, content));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
