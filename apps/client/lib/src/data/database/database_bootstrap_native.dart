import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

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
    DatabaseRecoveryCode.databaseOpenFailed => '학습 데이터를 열지 못했습니다',
    DatabaseRecoveryCode.databaseLocationUnavailable => '학습 데이터 위치에 접근하지 못했습니다',
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

  String get clipboardText {
    final detected = detectedSchemaVersion?.toString() ?? 'unknown';
    final size = databaseByteLength?.toString() ?? 'unknown';
    return [
      'Sprache database recovery',
      'code: ${code.stableCode}',
      'schema: $detected / expected: $expectedSchemaVersion',
      'bytes: $size',
      'preserved files: ${preservedFiles.length}',
      'time: ${preservedAt.toUtc().toIso8601String()}',
      'technical: $technicalSummary',
    ].join('\n');
  }
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

typedef DatabasePathResolver = Future<String> Function();
typedef AppDatabaseOpener = Future<AppDatabase> Function();

class DatabaseBootstrapService implements DatabaseBootstrapper {
  DatabaseBootstrapService({
    DatabasePathResolver? databasePathResolver,
    AppDatabaseOpener? openDatabase,
    DateTime Function()? clock,
  }) : _databasePathResolver = databasePathResolver ?? _defaultDatabasePath,
       _openDatabase = openDatabase ?? _openDefaultDatabase,
       _clock = clock ?? DateTime.now;

  final DatabasePathResolver _databasePathResolver;
  final AppDatabaseOpener _openDatabase;
  final DateTime Function() _clock;

  @override
  Future<DatabaseBootstrapResult> open() async {
    String databasePath;
    try {
      databasePath = await _databasePathResolver();
    } catch (error) {
      return DatabaseRecoveryRequired(
        _diagnostic(
          code: DatabaseRecoveryCode.databaseLocationUnavailable,
          summary: '운영체제의 앱 데이터 폴더를 읽지 못해 원본을 건드리지 않았습니다.',
          technicalSummary: _safeError(error),
        ),
      );
    }

    final databaseFile = File(databasePath);
    final exists = await databaseFile.exists();
    int? detectedVersion;
    FileStat? databaseStat;
    if (exists) {
      databaseStat = await databaseFile.stat();
      final inspection = await _inspectSqliteHeader(databaseFile);
      if (!inspection.valid) {
        final preserved = await _tryPreserve(databaseFile, 'invalid-header');
        return DatabaseRecoveryRequired(
          _diagnostic(
            code: DatabaseRecoveryCode.invalidDatabase,
            summary: 'SQLite 파일 헤더가 올바르지 않아 자동 복구나 초기화를 시도하지 않았습니다.',
            databaseStat: databaseStat,
            preservedFiles: preserved.files,
            technicalSummary: preserved.error ?? inspection.reason,
          ),
        );
      }
      detectedVersion = inspection.userVersion;
      if (detectedVersion > AppDatabase.currentSchemaVersion) {
        final preserved = await _tryPreserve(databaseFile, 'newer-schema');
        return DatabaseRecoveryRequired(
          _diagnostic(
            code: DatabaseRecoveryCode.newerSchema,
            summary:
                '현재 앱은 이 데이터 형식을 안전하게 읽을 수 없습니다. Sprache를 업데이트한 뒤 다시 시도해 주세요.',
            detectedSchemaVersion: detectedVersion,
            databaseStat: databaseStat,
            preservedFiles: preserved.files,
            technicalSummary:
                preserved.error ??
                'database schema $detectedVersion is newer than '
                    '${AppDatabase.currentSchemaVersion}',
          ),
        );
      }
    }

    List<PreservedDatabaseFile> preMigrationFiles = const [];
    if (exists &&
        detectedVersion != null &&
        detectedVersion < AppDatabase.currentSchemaVersion) {
      final preserved = await _tryPreserve(databaseFile, 'pre-migration');
      if (preserved.error != null || preserved.files.isEmpty) {
        return DatabaseRecoveryRequired(
          _diagnostic(
            code: DatabaseRecoveryCode.migrationBackupFailed,
            summary: '업그레이드 전 안전 사본을 만들 수 없어 마이그레이션을 시작하지 않았습니다.',
            detectedSchemaVersion: detectedVersion,
            databaseStat: databaseStat,
            preservedFiles: preserved.files,
            technicalSummary:
                preserved.error ?? 'pre-migration copy was not created',
          ),
        );
      }
      preMigrationFiles = preserved.files;
    }

    try {
      return DatabaseReady(await _openDatabase());
    } catch (error) {
      final preserved = preMigrationFiles.isNotEmpty
          ? (files: preMigrationFiles, error: null)
          : await _tryPreserve(databaseFile, 'open-failed');
      final migrationFailed =
          detectedVersion != null &&
          detectedVersion < AppDatabase.currentSchemaVersion;
      return DatabaseRecoveryRequired(
        _diagnostic(
          code: migrationFailed
              ? DatabaseRecoveryCode.migrationFailed
              : DatabaseRecoveryCode.databaseOpenFailed,
          summary: migrationFailed
              ? '업그레이드 전 데이터 사본을 보존했으며 일부 변경도 적용하지 않았습니다.'
              : '원본 학습 데이터를 보존하고 쓰기 기능을 잠갔습니다.',
          detectedSchemaVersion: detectedVersion,
          databaseStat: databaseStat,
          preservedFiles: preserved.files,
          technicalSummary: _safeError(
            error,
            databasePath: databaseFile.path,
            fallback: preserved.error,
          ),
        ),
      );
    }
  }

  @override
  Future<Uint8List> createRecoveryArchive(
    DatabaseRecoveryDiagnostic diagnostic,
  ) async {
    final archive = Archive();
    for (final preserved in diagnostic.preservedFiles) {
      final bytes = await File(preserved.path).readAsBytes();
      archive.addFile(ArchiveFile(preserved.archiveName, bytes.length, bytes));
    }
    final manifest = utf8.encode(
      const JsonEncoder.withIndent('  ').convert({
        'format': 'sprache-database-recovery-v1',
        'createdAt': _clock().toUtc().toIso8601String(),
        'diagnostic': {
          'code': diagnostic.code.stableCode,
          'expectedSchemaVersion': diagnostic.expectedSchemaVersion,
          'detectedSchemaVersion': diagnostic.detectedSchemaVersion,
          'databaseByteLength': diagnostic.databaseByteLength,
          'databaseModifiedAt': diagnostic.databaseModifiedAt
              ?.toUtc()
              .toIso8601String(),
          'technicalSummary': diagnostic.technicalSummary,
        },
        'files': [
          for (final file in diagnostic.preservedFiles)
            {
              'name': file.archiveName,
              'byteLength': file.byteLength,
              'sha256': file.sha256,
            },
        ],
      }),
    );
    archive.addFile(
      ArchiveFile('recovery-manifest.json', manifest.length, manifest),
    );
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  DatabaseRecoveryDiagnostic _diagnostic({
    required DatabaseRecoveryCode code,
    required String summary,
    int? detectedSchemaVersion,
    FileStat? databaseStat,
    List<PreservedDatabaseFile> preservedFiles = const [],
    required String technicalSummary,
  }) {
    return DatabaseRecoveryDiagnostic(
      code: code,
      summary: summary,
      expectedSchemaVersion: AppDatabase.currentSchemaVersion,
      detectedSchemaVersion: detectedSchemaVersion,
      databaseByteLength: databaseStat?.size,
      databaseModifiedAt: databaseStat?.modified.toUtc(),
      preservedFiles: List.unmodifiable(preservedFiles),
      preservedAt: _clock().toUtc(),
      technicalSummary: technicalSummary,
    );
  }

  Future<({List<PreservedDatabaseFile> files, String? error})> _tryPreserve(
    File databaseFile,
    String reason,
  ) async {
    if (!await databaseFile.exists()) {
      return (files: const <PreservedDatabaseFile>[], error: null);
    }
    try {
      final timestamp = _clock().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final recoveryDirectory = Directory(
        '${databaseFile.parent.path}${Platform.pathSeparator}'
        'sprache-recovery${Platform.pathSeparator}$timestamp-$reason',
      );
      await recoveryDirectory.create(recursive: true);
      final candidates = [
        (file: databaseFile, name: 'sprache.sqlite'),
        (file: File('${databaseFile.path}-wal'), name: 'sprache.sqlite-wal'),
        (file: File('${databaseFile.path}-shm'), name: 'sprache.sqlite-shm'),
      ];
      final preserved = <PreservedDatabaseFile>[];
      for (final candidate in candidates) {
        if (!await candidate.file.exists()) continue;
        final destination = File(
          '${recoveryDirectory.path}${Platform.pathSeparator}${candidate.name}',
        );
        await candidate.file.copy(destination.path);
        final bytes = await destination.readAsBytes();
        preserved.add(
          PreservedDatabaseFile(
            path: destination.path,
            archiveName: candidate.name,
            byteLength: bytes.length,
            sha256: sha256.convert(bytes).toString(),
          ),
        );
      }
      return (
        files: List<PreservedDatabaseFile>.unmodifiable(preserved),
        error: null,
      );
    } catch (error) {
      return (files: const <PreservedDatabaseFile>[], error: _safeError(error));
    }
  }

  static Future<String> _defaultDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}sprache.sqlite';
  }

  static Future<AppDatabase> _openDefaultDatabase() async {
    final database = AppDatabase.defaults();
    try {
      await database.customSelect('SELECT 1').get();
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  static Future<_SqliteHeaderInspection> _inspectSqliteHeader(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      final bytes = await handle.read(100);
      if (bytes.length < 100) {
        return const _SqliteHeaderInspection.invalid(
          'database file is shorter than the SQLite header',
        );
      }
      const magic = <int>[
        0x53,
        0x51,
        0x4c,
        0x69,
        0x74,
        0x65,
        0x20,
        0x66,
        0x6f,
        0x72,
        0x6d,
        0x61,
        0x74,
        0x20,
        0x33,
        0x00,
      ];
      for (var index = 0; index < magic.length; index++) {
        if (bytes[index] != magic[index]) {
          return const _SqliteHeaderInspection.invalid(
            'database file does not have a SQLite 3 header',
          );
        }
      }
      final userVersion =
          (bytes[60] << 24) | (bytes[61] << 16) | (bytes[62] << 8) | bytes[63];
      return _SqliteHeaderInspection.valid(userVersion);
    } catch (error) {
      return _SqliteHeaderInspection.invalid(_safeError(error));
    } finally {
      await handle?.close();
    }
  }

  static String _safeError(
    Object error, {
    String? databasePath,
    String? fallback,
  }) {
    var source = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (databasePath != null && databasePath.isNotEmpty) {
      source = source.replaceAll(databasePath, 'sprache.sqlite');
    }
    source = source
        .replaceAll(RegExp(r'[A-Za-z]:\\[^\s,;]+'), '<local-path>')
        .replaceAll(RegExp(r'/(?:Users|home)/[^\s,;]+'), '<local-path>');
    if (source.isEmpty) source = fallback ?? error.runtimeType.toString();
    if (source.length > 600) source = '${source.substring(0, 600)}…';
    return source;
  }
}

class _SqliteHeaderInspection {
  const _SqliteHeaderInspection.valid(this.userVersion)
    : valid = true,
      reason = '';

  const _SqliteHeaderInspection.invalid(this.reason)
    : valid = false,
      userVersion = 0;

  final bool valid;
  final int userVersion;
  final String reason;
}
