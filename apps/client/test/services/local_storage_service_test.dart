import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/services/local_storage_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/sync/sync_dataset.dart';

void main() {
  late Directory sandbox;
  late Map<String, Object?> archive;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'sprache-local-storage-test-',
    );
    archive = await _buildValidArchive();
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test(
    'an empty selected folder is normalized and verified as writable',
    () async {
      String? receivedInitialDirectory;
      final backend = FileSystemLocalStorageBackend(
        directoryPicker: ({String? initialDirectory}) async {
          receivedInitialDirectory = initialDirectory;
          return sandbox.path;
        },
      );

      final picked = await backend.pickLocation();
      expect(receivedInitialDirectory, isNull);
      expect(picked, isNotNull);
      expect(picked!.locationId, Directory(sandbox.path).absolute.path);
      expect(picked.kind, LocalStorageLocationKind.fileSystemPath);

      final verified = await backend.verifyLocation(picked);
      final storageRoot = Directory(path.join(sandbox.path, 'Sprache'));

      expect(verified.locationId, picked.locationId);
      expect(verified.displayName, 'Sprache');
      expect(await storageRoot.exists(), isTrue);
      expect(
        await storageRoot
            .list()
            .where(
              (entity) => path
                  .basename(entity.path)
                  .startsWith('.sprache-write-check-'),
            )
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'bundle records segmented-v1 sections and a verified full backup',
    () async {
      final backend = FileSystemLocalStorageBackend();
      final location = _location(sandbox);
      final bundle = const LocalStorageBundleBuilder().build(
        archive,
        now: DateTime.utc(2026, 7, 30, 10),
      );
      final manifest = _jsonMap(bundle.manifestBytes);
      final files = Map<String, Object?>.from(
        manifest['files']! as Map<Object?, Object?>,
      );

      expect(manifest['schemaVersion'], 1);
      expect(manifest['layout'], SyncDatasetCodec.layout);
      expect(manifest['storageKind'], 'local-mirror');
      expect(
        files.keys,
        containsAll(<String>[
          ...SyncDatasetCodec.sectionPaths,
          'backups/latest.json',
        ]),
      );

      for (final file in bundle.files) {
        final entry = Map<String, Object?>.from(
          files[file.logicalPath]! as Map<Object?, Object?>,
        );
        expect(entry['relativePath'], file.relativePath);
        expect(entry['sha256'], sha256.convert(file.bytes).toString());
        expect(entry['byteLength'], file.bytes.length);
      }

      final result = await backend.writeBundle(
        location: location,
        bundle: bundle,
      );
      final expectedArchiveBytes = utf8.encode(jsonEncode(archive));
      final storageRoot = Directory(path.join(sandbox.path, 'Sprache'));

      expect(result.sha256Hex, sha256.convert(expectedArchiveBytes).toString());
      expect(result.byteLength, expectedArchiveBytes.length);
      for (final file in bundle.files) {
        final stored = File(path.join(storageRoot.path, file.relativePath));
        expect(await stored.exists(), isTrue, reason: file.relativePath);
        expect(await stored.readAsBytes(), file.bytes);
      }

      final restored = await backend.readLatestArchive(location);
      expect(restored, isNotNull);
      expect(sha256.convert(restored!).toString(), result.sha256Hex);
      expect(restored.length, result.byteLength);
      expect(jsonDecode(utf8.decode(restored)), archive);
    },
  );

  test(
    'manifest rotation retains two generations and removes older files',
    () async {
      final backend = FileSystemLocalStorageBackend();
      final location = _location(sandbox);
      final builder = const LocalStorageBundleBuilder();
      final first = builder.build(
        archive,
        now: DateTime.utc(2026, 7, 30, 10, 0, 0, 0, 1),
      );
      final second = builder.build(
        archive,
        now: DateTime.utc(2026, 7, 30, 10, 0, 0, 0, 2),
      );
      final third = builder.build(
        archive,
        now: DateTime.utc(2026, 7, 30, 10, 0, 0, 0, 3),
      );

      await backend.writeBundle(location: location, bundle: first);
      await backend.writeBundle(location: location, bundle: second);
      await backend.writeBundle(location: location, bundle: third);

      final storageRoot = Directory(path.join(sandbox.path, 'Sprache'));
      final current = _jsonMap(
        await File(path.join(storageRoot.path, 'manifest.json')).readAsBytes(),
      );
      final previous = _jsonMap(
        await File(
          path.join(storageRoot.path, 'manifest.previous.json'),
        ).readAsBytes(),
      );

      expect(current['datasetVersion'], int.parse(third.generation));
      expect(previous['datasetVersion'], int.parse(second.generation));
      for (final relativePath in third.relativePaths) {
        expect(
          await File(path.join(storageRoot.path, relativePath)).exists(),
          isTrue,
        );
      }
      for (final relativePath in second.relativePaths) {
        expect(
          await File(path.join(storageRoot.path, relativePath)).exists(),
          isTrue,
        );
      }
      for (final relativePath in first.relativePaths) {
        expect(
          await File(path.join(storageRoot.path, relativePath)).exists(),
          isFalse,
          reason: 'the oldest generation must be cleaned: $relativePath',
        );
      }
    },
  );

  test(
    'a damaged current manifest or archive falls back to previous',
    () async {
      final backend = FileSystemLocalStorageBackend();
      final location = _location(sandbox);
      final builder = const LocalStorageBundleBuilder();
      final firstArchive = Map<String, Object?>.from(archive)
        ..['exportedAt'] = DateTime.utc(2026, 7, 30, 10).toIso8601String();
      final secondArchive = Map<String, Object?>.from(archive)
        ..['exportedAt'] = DateTime.utc(2026, 7, 30, 11).toIso8601String();
      final first = builder.build(
        firstArchive,
        now: DateTime.utc(2026, 7, 30, 10),
      );
      final second = builder.build(
        secondArchive,
        now: DateTime.utc(2026, 7, 30, 11),
      );
      await backend.writeBundle(location: location, bundle: first);
      await backend.writeBundle(location: location, bundle: second);

      final storageRoot = Directory(path.join(sandbox.path, 'Sprache'));
      final currentManifest = File(
        path.join(storageRoot.path, 'manifest.json'),
      );
      final currentManifestBytes = await currentManifest.readAsBytes();

      await currentManifest.writeAsString('{damaged', flush: true);
      expect(
        await backend.readLatestArchive(location),
        orderedEquals(
          first.files
              .singleWhere((file) => file.logicalPath == 'backups/latest.json')
              .bytes,
        ),
      );

      await currentManifest.writeAsBytes(currentManifestBytes, flush: true);
      final currentBackup = second.files.singleWhere(
        (file) => file.logicalPath == 'backups/latest.json',
      );
      await File(
        path.join(storageRoot.path, currentBackup.relativePath),
      ).writeAsString('corrupted archive', flush: true);
      expect(
        await backend.readLatestArchive(location),
        orderedEquals(
          first.files
              .singleWhere((file) => file.logicalPath == 'backups/latest.json')
              .bytes,
        ),
      );
    },
  );

  test(
    'oversized backup declarations are rejected before restore reads',
    () async {
      final backend = FileSystemLocalStorageBackend();
      final location = _location(sandbox);
      final storageRoot = Directory(path.join(sandbox.path, 'Sprache'));
      final backups = Directory(path.join(storageRoot.path, 'backups'));
      await backups.create(recursive: true);
      final archiveFile = File(
        path.join(backups.path, 'archive-malicious.json'),
      );
      await archiveFile.writeAsString('{}', flush: true);
      await File(path.join(storageRoot.path, 'manifest.json')).writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'layout': SyncDatasetCodec.layout,
          'files': {
            'backups/latest.json': {
              'relativePath': 'backups/archive-malicious.json',
              'sha256': sha256.convert(utf8.encode('{}')).toString(),
              'byteLength': 10 * 1024 * 1024 + 1,
            },
          },
        }),
        flush: true,
      );

      expect(await backend.readLatestArchive(location), isNull);
    },
  );

  test('bundle paths cannot traverse outside the Sprache root', () async {
    final backend = FileSystemLocalStorageBackend();
    final bytes = Uint8List.fromList(utf8.encode('{}'));
    final malicious = LocalStorageBundle(
      generation: '123',
      files: [
        LocalStorageBundleFile(
          logicalPath: 'state/meta.json',
          relativePath: '../escaped.json',
          bytes: bytes,
          sha256Hex: sha256.convert(bytes).toString(),
        ),
      ],
      manifestBytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'layout': SyncDatasetCodec.layout,
            'files': <String, Object?>{},
          }),
        ),
      ),
      archiveSha256: sha256.convert(bytes).toString(),
      archiveBytes: bytes.length,
    );

    await expectLater(
      backend.writeBundle(location: _location(sandbox), bundle: malicious),
      throwsA(
        isA<LocalStorageException>().having(
          (error) => error.code,
          'code',
          'local_path_invalid',
        ),
      ),
    );
    expect(
      await File(path.join(sandbox.path, 'escaped.json')).exists(),
      isFalse,
    );
  });

  test(
    'import archiving sanitizes names and deduplicates identical bytes',
    () async {
      final backend = FileSystemLocalStorageBackend();
      final bytes = Uint8List.fromList(utf8.encode('word,meaning\nhello,안녕'));
      final fingerprint = sha256.convert(bytes).toString();
      final location = _location(sandbox);

      final first = await backend.archiveImport(
        location: location,
        originalFileName: r'..\..\unsafe:name.xlsx',
        bytes: bytes,
        sha256Hex: fingerprint,
      );
      final second = await backend.archiveImport(
        location: location,
        originalFileName: r'..\..\unsafe:name.xlsx',
        bytes: bytes,
        sha256Hex: fingerprint,
      );

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(second.relativePath, first.relativePath);
      expect(first.relativePath, isNot(contains('..')));
      final imports = Directory(path.join(sandbox.path, 'Sprache', 'imports'));
      expect(await imports.list().where((entity) => entity is File).length, 1);
      expect(
        await File(
          path.join(imports.path, path.basename(first.relativePath)),
        ).readAsBytes(),
        bytes,
      );
    },
  );

  test(
    'staged imports survive restart, validate sha, dedupe, and remove',
    () async {
      final stagingDirectory = Directory(path.join(sandbox.path, 'staging'));
      Future<Directory> directoryProvider() async => stagingDirectory;
      final bytes = Uint8List.fromList(utf8.encode('staged import payload'));
      final fingerprint = sha256.convert(bytes).toString();
      final firstService = FileImportArchiveStagingService(
        directoryProvider: directoryProvider,
      );

      final first = await firstService.stage(
        originalFileName: '../../words.xlsx',
        bytes: bytes,
        sha256Hex: fingerprint,
        distributionKey: ' work ',
      );
      await firstService.stage(
        originalFileName: 'words-renamed.xlsx',
        bytes: bytes,
        sha256Hex: fingerprint,
        distributionKey: 'work',
      );

      expect(
        await stagingDirectory.list().where((entity) => entity is File).length,
        2,
        reason: 'one metadata file and one data file are retained per sha',
      );

      final restarted = FileImportArchiveStagingService(
        directoryProvider: directoryProvider,
      );
      var listed = await restarted.list();
      expect(listed, hasLength(1));
      expect(listed.single.id, fingerprint);
      expect(listed.single.sha256Hex, fingerprint);
      expect(listed.single.bytes, bytes);
      expect(listed.single.originalFileName, 'words-renamed.xlsx');
      expect(listed.single.distributionKey, 'work');

      await File(
        path.join(stagingDirectory.path, '$fingerprint.bin'),
      ).writeAsString('tampered', flush: true);
      expect(await restarted.list(), isEmpty);

      final repaired = await restarted.stage(
        originalFileName: 'words.xlsx',
        bytes: bytes,
        sha256Hex: fingerprint,
      );
      listed = await FileImportArchiveStagingService(
        directoryProvider: directoryProvider,
      ).list();
      expect(listed, hasLength(1));
      expect(sha256.convert(listed.single.bytes).toString(), fingerprint);

      await expectLater(
        restarted.remove('../outside'),
        throwsA(
          isA<LocalStorageException>().having(
            (error) => error.code,
            'code',
            'staged_import_id_invalid',
          ),
        ),
      );
      await restarted.remove(repaired.id);
      expect(await restarted.list(), isEmpty);
      expect(
        await stagingDirectory.list().where((entity) => entity is File).isEmpty,
        isTrue,
      );
      expect(first.id, fingerprint);
    },
  );
}

Future<Map<String, Object?>> _buildValidArchive() async {
  final controller = AppController(MemoryStudyStore());
  await _waitFor(() => controller.state.isHydrated);
  final archive = controller.exportArchive();
  controller.dispose();
  return archive;
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before the test timeout.');
}

LocalStorageLocation _location(Directory directory) => LocalStorageLocation(
  locationId: directory.path,
  displayName: path.basename(directory.path),
  kind: LocalStorageLocationKind.fileSystemPath,
);

Map<String, Object?> _jsonMap(List<int> bytes) => Map<String, Object?>.from(
  jsonDecode(utf8.decode(bytes)) as Map<Object?, Object?>,
);
