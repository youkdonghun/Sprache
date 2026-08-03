import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import '../backup/backup_archive.dart';
import '../domain/local_storage.dart';
import '../sync/sync_dataset.dart';

class LocalStorageException implements Exception {
  const LocalStorageException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class LocalStorageLocation {
  const LocalStorageLocation({
    required this.locationId,
    required this.displayName,
    required this.kind,
  });

  final String locationId;
  final String displayName;
  final LocalStorageLocationKind kind;
}

class LocalStorageBundleFile {
  const LocalStorageBundleFile({
    required this.logicalPath,
    required this.relativePath,
    required this.bytes,
    required this.sha256Hex,
  });

  final String logicalPath;
  final String relativePath;
  final Uint8List bytes;
  final String sha256Hex;

  Map<String, Object?> toChannelArguments() => {
    'logicalPath': logicalPath,
    'relativePath': relativePath,
    'bytes': bytes,
    'sha256': sha256Hex,
  };
}

class LocalStorageBundle {
  const LocalStorageBundle({
    required this.generation,
    required this.files,
    required this.manifestBytes,
    required this.archiveSha256,
    required this.archiveBytes,
  });

  final String generation;
  final List<LocalStorageBundleFile> files;
  final Uint8List manifestBytes;
  final String archiveSha256;
  final int archiveBytes;

  List<String> get relativePaths =>
      files.map((file) => file.relativePath).toList(growable: false);
}

class LocalStorageWriteResult {
  const LocalStorageWriteResult({
    required this.savedAt,
    required this.sha256Hex,
    required this.byteLength,
  });

  final DateTime savedAt;
  final String sha256Hex;
  final int byteLength;
}

class LocalImportArchiveResult {
  const LocalImportArchiveResult({
    required this.created,
    required this.relativePath,
  });

  final bool created;
  final String relativePath;
}

class StagedImportArchive {
  const StagedImportArchive({
    required this.id,
    required this.originalFileName,
    required this.sha256Hex,
    required this.bytes,
    required this.createdAt,
    this.distributionKey,
  });

  final String id;
  final String originalFileName;
  final String sha256Hex;
  final Uint8List bytes;
  final DateTime createdAt;
  final String? distributionKey;
}

abstract interface class ImportArchiveStagingService {
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  });

  Future<List<StagedImportArchive>> list();

  Future<void> remove(String id);
}

/// Browser imports are held only for the active session. The normalized
/// learning data and import draft are persisted in Drift/IndexedDB instead,
/// while the user's original file is never uploaded or retained implicitly.
class MemoryImportArchiveStagingService implements ImportArchiveStagingService {
  final Map<String, StagedImportArchive> _entries = {};

  @override
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  }) async {
    if (sha256.convert(bytes).toString() != sha256Hex) {
      throw const LocalStorageException(
        'staged_import_sha_mismatch',
        '가져올 원본 파일을 확인하지 못했습니다.',
      );
    }
    final entry = StagedImportArchive(
      id: sha256Hex.toLowerCase(),
      originalFileName: _safeFileName(originalFileName),
      sha256Hex: sha256Hex,
      bytes: Uint8List.fromList(bytes),
      createdAt: DateTime.now().toUtc(),
      distributionKey: distributionKey?.trim(),
    );
    _entries[entry.id] = entry;
    return entry;
  }

  @override
  Future<List<StagedImportArchive>> list() async => List.unmodifiable(
    _entries.values.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt)),
  );

  @override
  Future<void> remove(String id) async {
    _entries.remove(id);
  }
}

class FileImportArchiveStagingService implements ImportArchiveStagingService {
  FileImportArchiveStagingService({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
           directoryProvider ??
           (() async {
             try {
               final support = await getApplicationSupportDirectory();
               return Directory(
                 path.join(support.path, 'sprache-import-staging'),
               );
             } on MissingPluginException {
               // Flutter widget tests do not register path_provider. This
               // fallback is only used by that host process.
               return Directory(
                 path.join(
                   Directory.systemTemp.path,
                   'sprache-import-staging-test-$pid',
                 ),
               );
             }
           });

  final Future<Directory> Function() _directoryProvider;

  @override
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  }) async {
    if (sha256.convert(bytes).toString() != sha256Hex) {
      throw const LocalStorageException(
        'staged_import_sha_mismatch',
        '가져오기 원본의 무결성 확인에 실패했습니다.',
      );
    }
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final id = sha256Hex.toLowerCase();
    final dataFile = File(path.join(directory.path, '$id.bin'));
    final metadataFile = File(path.join(directory.path, '$id.json'));
    final existingDataIsValid =
        await dataFile.exists() &&
        sha256.convert(await dataFile.readAsBytes()).toString() == sha256Hex;
    if (!existingDataIsValid) {
      if (await dataFile.exists()) await dataFile.delete();
      final temporary = File('${dataFile.path}.next');
      await temporary.writeAsBytes(bytes, flush: true);
      final written = await temporary.readAsBytes();
      if (sha256.convert(written).toString() != sha256Hex) {
        await temporary.delete();
        throw const LocalStorageException(
          'staged_import_write_failed',
          '가져오기 원본의 임시 보관에 실패했습니다.',
        );
      }
      await temporary.rename(dataFile.path);
    }
    final createdAt = DateTime.now().toUtc();
    final metadata = {
      'schemaVersion': 1,
      'id': id,
      'originalFileName': _safeFileName(originalFileName),
      'sha256': sha256Hex,
      'createdAt': createdAt.toIso8601String(),
      if (distributionKey != null && distributionKey.trim().isNotEmpty)
        'distributionKey': distributionKey.trim(),
    };
    final temporaryMetadata = File('${metadataFile.path}.next');
    await temporaryMetadata.writeAsString(jsonEncode(metadata), flush: true);
    if (await metadataFile.exists()) await metadataFile.delete();
    await temporaryMetadata.rename(metadataFile.path);
    return StagedImportArchive(
      id: id,
      originalFileName: metadata['originalFileName']! as String,
      sha256Hex: sha256Hex,
      bytes: Uint8List.fromList(bytes),
      createdAt: createdAt,
      distributionKey: metadata['distributionKey'] as String?,
    );
  }

  @override
  Future<List<StagedImportArchive>> list() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) return const [];
    final staged = <StagedImportArchive>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final metadata = Map<String, Object?>.from(
          jsonDecode(await entity.readAsString()) as Map<Object?, Object?>,
        );
        if (metadata['schemaVersion'] != 1) continue;
        final id = metadata['id'] as String;
        final fingerprint = metadata['sha256'] as String;
        final dataFile = File(path.join(directory.path, '$id.bin'));
        if (!await dataFile.exists()) continue;
        final bytes = await dataFile.readAsBytes();
        if (sha256.convert(bytes).toString() != fingerprint) continue;
        staged.add(
          StagedImportArchive(
            id: id,
            originalFileName: metadata['originalFileName'] as String,
            sha256Hex: fingerprint,
            bytes: Uint8List.fromList(bytes),
            createdAt:
                DateTime.tryParse(
                  metadata['createdAt'] as String? ?? '',
                )?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            distributionKey: metadata['distributionKey'] as String?,
          ),
        );
      } catch (_) {
        // A malformed staging entry is retained for manual recovery.
      }
    }
    staged.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return List.unmodifiable(staged);
  }

  @override
  Future<void> remove(String id) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const LocalStorageException(
        'staged_import_id_invalid',
        '가져오기 원본 대기열 ID가 올바르지 않습니다.',
      );
    }
    final directory = await _directoryProvider();
    for (final extension in const ['json', 'bin']) {
      final file = File(path.join(directory.path, '$id.$extension'));
      if (await file.exists()) await file.delete();
    }
  }
}

typedef LocalDirectoryPicker =
    Future<String?> Function({String? initialDirectory});

abstract interface class LocalStorageBackend {
  Future<LocalStorageLocation?> pickLocation({LocalStorageSettings? current});

  Future<LocalStorageLocation> verifyLocation(LocalStorageLocation location);

  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  });

  Future<Uint8List?> readLatestArchive(LocalStorageLocation location);

  Future<bool> hasLatestArchive(LocalStorageLocation location);

  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  });

  Future<void> releaseLocation(LocalStorageLocation location);
}

class LocalStorageBundleBuilder {
  const LocalStorageBundleBuilder({
    this.datasetCodec = const SyncDatasetCodec(),
    this.archiveCodec = const BackupArchiveCodec(),
  });

  final SyncDatasetCodec datasetCodec;
  final BackupArchiveCodec archiveCodec;

  LocalStorageBundle build(Map<String, Object?> archive, {DateTime? now}) {
    archiveCodec.validate(archive);
    final writtenAt = (now ?? DateTime.now()).toUtc();
    final generation = writtenAt.microsecondsSinceEpoch.toString();
    final files = <LocalStorageBundleFile>[];
    final manifestFiles = <String, Object?>{};

    for (final entry in datasetCodec.split(archive).entries) {
      final relativePath = _versionedPath(entry.key, generation);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(entry.value)));
      final fingerprint = sha256.convert(bytes).toString();
      files.add(
        LocalStorageBundleFile(
          logicalPath: entry.key,
          relativePath: relativePath,
          bytes: bytes,
          sha256Hex: fingerprint,
        ),
      );
      manifestFiles[entry.key] = {
        'relativePath': relativePath,
        'sha256': fingerprint,
        'byteLength': bytes.length,
      };
    }

    final archiveBytes = Uint8List.fromList(utf8.encode(jsonEncode(archive)));
    if (archiveBytes.length > BackupArchiveCodec.maxArchiveBytes) {
      throw const LocalStorageException(
        'local_archive_too_large',
        '로컬 보관본이 10MB 제한을 넘었습니다.',
      );
    }
    final archiveFingerprint = sha256.convert(archiveBytes).toString();
    final archiveRelativePath = 'backups/archive-$generation.json';
    files.add(
      LocalStorageBundleFile(
        logicalPath: 'backups/latest.json',
        relativePath: archiveRelativePath,
        bytes: archiveBytes,
        sha256Hex: archiveFingerprint,
      ),
    );
    manifestFiles['backups/latest.json'] = {
      'relativePath': archiveRelativePath,
      'sha256': archiveFingerprint,
      'byteLength': archiveBytes.length,
    };

    final manifestBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'layout': SyncDatasetCodec.layout,
          'storageKind': 'local-mirror',
          'datasetVersion': int.parse(generation),
          'updatedAt': writtenAt.toIso8601String(),
          'files': manifestFiles,
        }),
      ),
    );
    return LocalStorageBundle(
      generation: generation,
      files: List.unmodifiable(files),
      manifestBytes: manifestBytes,
      archiveSha256: archiveFingerprint,
      archiveBytes: archiveBytes.length,
    );
  }

  String _versionedPath(String logicalPath, String generation) {
    if (!logicalPath.endsWith('.json')) {
      throw LocalStorageException(
        'local_path_invalid',
        '지원하지 않는 로컬 저장 경로입니다: $logicalPath',
      );
    }
    return '${logicalPath.substring(0, logicalPath.length - 5)}-$generation.json';
  }
}

LocalStorageBackend createPlatformLocalStorageBackend() {
  if (kIsWeb) return const BrowserLocalStorageBackend();
  if (defaultTargetPlatform == TargetPlatform.android) {
    return const AndroidSafLocalStorageBackend();
  }
  return FileSystemLocalStorageBackend();
}

class BrowserLocalStorageBackend implements LocalStorageBackend {
  const BrowserLocalStorageBackend();

  Never _unsupported() => throw const LocalStorageException(
    'browser_folder_not_supported',
    '브라우저에서는 로컬 폴더 자동 저장 대신 백업 내려받기와 불러오기를 사용해 주세요.',
  );

  @override
  Future<LocalStorageLocation?> pickLocation({
    LocalStorageSettings? current,
  }) async => _unsupported();

  @override
  Future<LocalStorageLocation> verifyLocation(
    LocalStorageLocation location,
  ) async => _unsupported();

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) async => _unsupported();

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) async =>
      _unsupported();

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) async =>
      _unsupported();

  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) async => _unsupported();

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {}
}

class FileSystemLocalStorageBackend implements LocalStorageBackend {
  FileSystemLocalStorageBackend({LocalDirectoryPicker? directoryPicker})
    : _directoryPicker =
          directoryPicker ??
          (({String? initialDirectory}) {
            return FilePicker.platform.getDirectoryPath(
              dialogTitle: 'Sprache 로컬 보관 폴더 선택',
              initialDirectory: initialDirectory,
              lockParentWindow: true,
            );
          });

  final LocalDirectoryPicker _directoryPicker;

  @override
  Future<LocalStorageLocation?> pickLocation({
    LocalStorageSettings? current,
  }) async {
    final selected = await _directoryPicker(
      initialDirectory:
          current?.locationKind == LocalStorageLocationKind.fileSystemPath
          ? current?.locationId
          : null,
    );
    if (selected == null || selected.trim().isEmpty) return null;
    final normalized = path.normalize(Directory(selected).absolute.path);
    return LocalStorageLocation(
      locationId: normalized,
      displayName: path.basename(normalized),
      kind: LocalStorageLocationKind.fileSystemPath,
    );
  }

  @override
  Future<LocalStorageLocation> verifyLocation(
    LocalStorageLocation location,
  ) async {
    final root = _storageRoot(location);
    try {
      await root.create(recursive: true);
      final probe = File(
        path.join(
          root.path,
          '.sprache-write-check-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      const content = 'sprache-local-storage-check';
      await probe.writeAsString(content, flush: true);
      if (await probe.readAsString() != content) {
        throw const FileSystemException('write verification failed');
      }
      await probe.delete();
      return LocalStorageLocation(
        locationId: location.locationId,
        displayName: path.basename(root.path),
        kind: LocalStorageLocationKind.fileSystemPath,
      );
    } catch (_) {
      throw const LocalStorageException(
        'local_folder_not_writable',
        '선택한 폴더에 저장할 수 없습니다. 다른 폴더를 선택해 주세요.',
      );
    }
  }

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) async {
    final root = _storageRoot(location);
    await root.create(recursive: true);
    final createdFiles = <File>[];
    try {
      for (final bundleFile in bundle.files) {
        final target = _resolveRelativeFile(root, bundleFile.relativePath);
        await target.parent.create(recursive: true);
        final temporary = File('${target.path}.next-${bundle.generation}');
        await temporary.writeAsBytes(bundleFile.bytes, flush: true);
        await _verifyFile(
          temporary,
          expectedSha256: bundleFile.sha256Hex,
          expectedLength: bundleFile.bytes.length,
        );
        if (await target.exists()) {
          throw const LocalStorageException(
            'local_generation_conflict',
            '같은 로컬 저장 세대가 이미 존재합니다. 다시 시도해 주세요.',
          );
        }
        await temporary.rename(target.path);
        createdFiles.add(target);
      }

      final manifest = File(path.join(root.path, 'manifest.json'));
      final previousManifest = File(
        path.join(root.path, 'manifest.previous.json'),
      );
      final nextManifest = File(
        path.join(root.path, 'manifest.next-${bundle.generation}.json'),
      );
      await nextManifest.writeAsBytes(bundle.manifestBytes, flush: true);
      _decodeManifest(await nextManifest.readAsBytes());
      if (await previousManifest.exists()) await previousManifest.delete();
      var rotated = false;
      if (await manifest.exists()) {
        await manifest.rename(previousManifest.path);
        rotated = true;
      }
      try {
        await nextManifest.rename(manifest.path);
      } catch (_) {
        if (rotated &&
            !await manifest.exists() &&
            await previousManifest.exists()) {
          await previousManifest.rename(manifest.path);
        }
        rethrow;
      }
      await _cleanupOldGenerations(root);
      return LocalStorageWriteResult(
        savedAt: DateTime.now().toUtc(),
        sha256Hex: bundle.archiveSha256,
        byteLength: bundle.archiveBytes,
      );
    } catch (error) {
      for (final file in createdFiles) {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            // A failed cleanup must not hide the original write failure.
          }
        }
      }
      if (error is LocalStorageException) rethrow;
      throw const LocalStorageException(
        'local_write_failed',
        '로컬 보관본을 저장하지 못했습니다. 폴더 연결을 확인해 주세요.',
      );
    }
  }

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) async {
    final root = _storageRoot(location);
    for (final manifestName in const [
      'manifest.json',
      'manifest.previous.json',
    ]) {
      final manifestFile = File(path.join(root.path, manifestName));
      if (!await manifestFile.exists()) continue;
      try {
        final manifest = _decodeManifest(
          await _readFileBounded(
            manifestFile,
            maxBytes: _maxLocalManifestBytes,
            errorCode: 'local_manifest_too_large',
          ),
        );
        final entry = _manifestEntry(manifest, 'backups/latest.json');
        if (entry.byteLength <= 0 ||
            entry.byteLength > BackupArchiveCodec.maxArchiveBytes) {
          throw const LocalStorageException(
            'local_archive_too_large',
            'The local backup exceeds the safe restore size.',
          );
        }
        final archiveFile = _resolveRelativeFile(root, entry.relativePath);
        if (!await archiveFile.exists()) continue;
        if (await archiveFile.length() != entry.byteLength) continue;
        final bytes = await _readFileBounded(
          archiveFile,
          maxBytes: BackupArchiveCodec.maxArchiveBytes,
          errorCode: 'local_archive_too_large',
        );
        if (bytes.length != entry.byteLength ||
            sha256.convert(bytes).toString() != entry.sha256Hex) {
          continue;
        }
        return Uint8List.fromList(bytes);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) async =>
      await readLatestArchive(location) != null;

  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) async {
    if (sha256.convert(bytes).toString() != sha256Hex) {
      throw const LocalStorageException(
        'local_import_sha_mismatch',
        '가져오기 원본의 무결성 확인에 실패했습니다.',
      );
    }
    final root = _storageRoot(location);
    final imports = Directory(path.join(root.path, 'imports'));
    await imports.create(recursive: true);
    final safeName = _safeFileName(originalFileName);
    var target = File(
      path.join(imports.path, '${sha256Hex.substring(0, 12)}-$safeName'),
    );
    if (await target.exists()) {
      final existing = await target.readAsBytes();
      if (sha256.convert(existing).toString() == sha256Hex) {
        return LocalImportArchiveResult(
          created: false,
          relativePath: path.relative(target.path, from: root.path),
        );
      }
      target = File(
        path.join(
          imports.path,
          '${sha256Hex.substring(0, 12)}-'
          '${DateTime.now().microsecondsSinceEpoch}-$safeName',
        ),
      );
    }
    final temporary = File('${target.path}.next');
    await temporary.writeAsBytes(bytes, flush: true);
    await _verifyFile(
      temporary,
      expectedSha256: sha256Hex,
      expectedLength: bytes.length,
    );
    await temporary.rename(target.path);
    return LocalImportArchiveResult(
      created: true,
      relativePath: path.relative(target.path, from: root.path),
    );
  }

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {}

  Directory _storageRoot(LocalStorageLocation location) {
    if (location.kind != LocalStorageLocationKind.fileSystemPath ||
        location.locationId.trim().isEmpty) {
      throw const LocalStorageException(
        'local_location_invalid',
        '로컬 보관 폴더 정보가 올바르지 않습니다.',
      );
    }
    final selected = Directory(location.locationId).absolute;
    return path.basename(selected.path).toLowerCase() == 'sprache'
        ? selected
        : Directory(path.join(selected.path, 'Sprache'));
  }

  File _resolveRelativeFile(Directory root, String relativePath) {
    final segments = relativePath.replaceAll('\\', '/').split('/');
    if (segments.isEmpty ||
        segments.any(
          (segment) =>
              segment.isEmpty ||
              segment == '.' ||
              segment == '..' ||
              segment.contains(':'),
        )) {
      throw const LocalStorageException(
        'local_path_invalid',
        '로컬 저장 파일 경로가 올바르지 않습니다.',
      );
    }
    final resolved = path.normalize(path.joinAll([root.path, ...segments]));
    if (!path.isWithin(root.path, resolved)) {
      throw const LocalStorageException(
        'local_path_outside_root',
        '로컬 저장 폴더 밖의 경로는 사용할 수 없습니다.',
      );
    }
    return File(resolved);
  }

  Future<void> _verifyFile(
    File file, {
    required String expectedSha256,
    required int expectedLength,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.length != expectedLength ||
        sha256.convert(bytes).toString() != expectedSha256) {
      throw const LocalStorageException(
        'local_write_verification_failed',
        '기록한 로컬 파일의 무결성 확인에 실패했습니다.',
      );
    }
  }

  Future<void> _cleanupOldGenerations(Directory root) async {
    final keep = <String>{};
    for (final manifestName in const [
      'manifest.json',
      'manifest.previous.json',
    ]) {
      final manifestFile = File(path.join(root.path, manifestName));
      if (!await manifestFile.exists()) continue;
      try {
        final manifest = _decodeManifest(await manifestFile.readAsBytes());
        final files = manifest['files'];
        if (files is! Map) continue;
        for (final raw in files.values) {
          if (raw is! Map) continue;
          final relativePath = raw['relativePath'];
          if (relativePath is String) {
            keep.add(
              path.normalize(
                path.joinAll([
                  root.path,
                  ...relativePath.replaceAll('\\', '/').split('/'),
                ]),
              ),
            );
          }
        }
      } catch (_) {
        // Keep unknown generations if a previous manifest cannot be parsed.
        return;
      }
    }
    for (final folderName in const ['state', 'content', 'backups']) {
      final folder = Directory(path.join(root.path, folderName));
      if (!await folder.exists()) continue;
      await for (final entity in folder.list(recursive: true)) {
        if (entity is File &&
            entity.path.toLowerCase().endsWith('.json') &&
            !keep.contains(path.normalize(entity.path))) {
          try {
            await entity.delete();
          } catch (_) {
            // Retention cleanup is best effort after a committed manifest.
          }
        }
      }
    }
  }
}

class AndroidSafLocalStorageBackend implements LocalStorageBackend {
  const AndroidSafLocalStorageBackend();

  static const _channel = MethodChannel(
    'com.youkdonghun.sprache/local_storage',
  );

  @override
  Future<LocalStorageLocation?> pickLocation({
    LocalStorageSettings? current,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'pickDirectory',
    );
    if (raw == null) return null;
    return _locationFromChannel(raw);
  }

  @override
  Future<LocalStorageLocation> verifyLocation(
    LocalStorageLocation location,
  ) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'verifyDirectory',
        {'locationId': location.locationId},
      );
      if (raw == null) {
        throw const LocalStorageException(
          'local_permission_missing',
          '선택한 Android 폴더 권한을 다시 허용해 주세요.',
        );
      }
      return LocalStorageLocation(
        locationId: location.locationId,
        displayName: raw['displayName']?.toString().trim().isNotEmpty == true
            ? raw['displayName']!.toString()
            : location.displayName,
        kind: LocalStorageLocationKind.androidDocumentTree,
      );
    } on PlatformException catch (error) {
      throw LocalStorageException(
        error.code,
        error.message ?? '선택한 Android 폴더 권한을 확인할 수 없습니다.',
      );
    }
  }

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) async {
    try {
      await _channel.invokeMethod<void>('writeBundle', {
        'locationId': location.locationId,
        'files': [for (final file in bundle.files) file.toChannelArguments()],
        'manifestBytes': bundle.manifestBytes,
        'keepRelativePaths': bundle.relativePaths,
      });
      return LocalStorageWriteResult(
        savedAt: DateTime.now().toUtc(),
        sha256Hex: bundle.archiveSha256,
        byteLength: bundle.archiveBytes,
      );
    } on PlatformException catch (error) {
      throw LocalStorageException(
        error.code,
        error.message ?? 'Android 로컬 보관본을 저장하지 못했습니다.',
      );
    }
  }

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) async {
    try {
      return await _channel.invokeMethod<Uint8List>('readLatestArchive', {
        'locationId': location.locationId,
      });
    } on PlatformException catch (error) {
      throw LocalStorageException(
        error.code,
        error.message ?? 'Android 로컬 보관본을 읽지 못했습니다.',
      );
    }
  }

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) async {
    try {
      return await _channel.invokeMethod<bool>('hasLatestArchive', {
            'locationId': location.locationId,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw LocalStorageException(
        error.code,
        error.message ?? 'Android 로컬 보관본을 확인하지 못했습니다.',
      );
    }
  }

  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, Object?>('archiveImport', {
            'locationId': location.locationId,
            'fileName': originalFileName,
            'bytes': bytes,
            'sha256': sha256Hex,
          });
      if (raw == null) {
        throw const LocalStorageException(
          'local_import_archive_failed',
          '가져오기 원본을 로컬 폴더에 보관하지 못했습니다.',
        );
      }
      return LocalImportArchiveResult(
        created: raw['created'] == true,
        relativePath: raw['relativePath']?.toString() ?? '',
      );
    } on PlatformException catch (error) {
      throw LocalStorageException(
        error.code,
        error.message ?? '가져오기 원본을 Android 폴더에 보관하지 못했습니다.',
      );
    }
  }

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {
    try {
      await _channel.invokeMethod<void>('releaseDirectory', {
        'locationId': location.locationId,
      });
    } on PlatformException {
      // Releasing an already revoked permission is intentionally idempotent.
    }
  }

  LocalStorageLocation _locationFromChannel(Map<String, Object?> raw) {
    final locationId = raw['locationId']?.toString().trim() ?? '';
    final displayName = raw['displayName']?.toString().trim() ?? '';
    if (locationId.isEmpty || displayName.isEmpty) {
      throw const LocalStorageException(
        'local_picker_invalid_result',
        '선택한 Android 폴더 정보를 읽지 못했습니다.',
      );
    }
    return LocalStorageLocation(
      locationId: locationId,
      displayName: displayName,
      kind: LocalStorageLocationKind.androidDocumentTree,
    );
  }
}

Map<String, Object?> _decodeManifest(List<int> bytes) {
  final raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (raw is! Map) {
    throw const LocalStorageException(
      'local_manifest_invalid',
      '로컬 manifest 형식이 올바르지 않습니다.',
    );
  }
  final manifest = Map<String, Object?>.from(raw);
  if (manifest['schemaVersion'] != 1 ||
      manifest['layout'] != SyncDatasetCodec.layout ||
      manifest['files'] is! Map) {
    throw const LocalStorageException(
      'local_manifest_invalid',
      '지원하지 않거나 손상된 로컬 manifest입니다.',
    );
  }
  return manifest;
}

const int _maxLocalManifestBytes = 1024 * 1024;

Future<Uint8List> _readFileBounded(
  File file, {
  required int maxBytes,
  required String errorCode,
}) async {
  final declaredLength = await file.length();
  if (declaredLength < 0 || declaredLength > maxBytes) {
    throw LocalStorageException(errorCode, 'The local file is too large.');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (chunk.length > maxBytes - builder.length) {
      throw LocalStorageException(errorCode, 'The local file is too large.');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

({String relativePath, String sha256Hex, int byteLength}) _manifestEntry(
  Map<String, Object?> manifest,
  String logicalPath,
) {
  final files = manifest['files'];
  final raw = files is Map ? files[logicalPath] : null;
  if (raw is! Map) {
    throw const LocalStorageException(
      'local_archive_missing',
      '로컬 보관본 항목이 없습니다.',
    );
  }
  final relativePath = raw['relativePath'];
  final fingerprint = raw['sha256'];
  final byteLength = raw['byteLength'];
  if (relativePath is! String || fingerprint is! String || byteLength is! num) {
    throw const LocalStorageException(
      'local_manifest_entry_invalid',
      '로컬 manifest 항목이 올바르지 않습니다.',
    );
  }
  return (
    relativePath: relativePath,
    sha256Hex: fingerprint,
    byteLength: byteLength.toInt(),
  );
}

String _safeFileName(String value) {
  final segments = value.trim().split(RegExp(r'[/\\]+'));
  final baseName = segments.reversed.firstWhere((segment) {
    final candidate = segment.trim();
    return candidate.isNotEmpty && candidate != '.' && candidate != '..';
  }, orElse: () => 'import-file');
  final safe = baseName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '')
      .trim();
  return safe.isEmpty ? 'import-file' : safe;
}
