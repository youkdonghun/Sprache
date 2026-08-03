import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/services/local_storage_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';

void main() {
  test(
    'legacy local folder metadata is retired without copying or deleting data',
    () async {
      final store = MemoryStudyStore(localStorageSettings: _configuredSettings);
      final backend = _FakeLocalStorageBackend();
      final app = AppController(store);
      final controller = _buildController(
        store: store,
        backend: backend,
        app: app,
      );

      await _initialize(app, controller);
      app.updatePreferences(app.state.preferences.copyWith(newItemLimit: 17));
      controller.observeAppState(app.state);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.state.configured, isFalse);
      expect(controller.state.activeTarget, ActiveStorageTarget.appOnly);
      expect(backend.writes, isEmpty);
      expect(backend.releasedLocations, hasLength(1));
      expect((await store.loadLocalStorageSettings()).configured, isFalse);

      controller.dispose();
      app.dispose();
    },
  );

  test('Drive is the only external storage target', () async {
    final store = MemoryStudyStore(localStorageSettings: _configuredSettings);
    final backend = _FakeLocalStorageBackend();
    final app = AppController(store);
    final controller = _buildController(
      store: store,
      backend: backend,
      app: app,
    );

    await _initialize(app, controller);
    app.setDriveConnected(true);
    controller.observeAppState(app.state);
    app.updatePreferences(app.state.preferences.copyWith(newItemLimit: 19));
    controller.observeAppState(app.state);
    await controller.saveNow();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.state.activeTarget, ActiveStorageTarget.googleDrive);
    expect(backend.writes, isEmpty);

    app.setDriveConnected(false);
    controller.observeAppState(app.state);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.state.activeTarget, ActiveStorageTarget.appOnly);
    expect(backend.writes, isEmpty);
    controller.dispose();
    app.dispose();
  });

  test(
    'legacy staged import originals are discarded without another copy',
    () async {
      final store = MemoryStudyStore(localStorageSettings: _configuredSettings);
      final backend = _FakeLocalStorageBackend();
      final staging = _MemoryImportStagingService();
      await staging.stage(
        originalFileName: 'vocabulary.xlsx',
        bytes: Uint8List.fromList(const [1, 2, 3]),
        sha256Hex:
            '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
        distributionKey: 'work',
      );
      final app = AppController(store);
      final controller = _buildController(
        store: store,
        backend: backend,
        app: app,
        importStaging: staging,
      );

      await _initialize(app, controller);

      expect(controller.state.pendingImportCount, 0);
      expect(backend.archivedImports, isEmpty);
      expect(await staging.list(), isEmpty);

      controller.dispose();
      app.dispose();
    },
  );
}

const _configuredSettings = LocalStorageSettings(
  locationId: 'configured-local-folder',
  displayName: 'Sprache',
  locationKind: LocalStorageLocationKind.fileSystemPath,
);

LocalStorageController _buildController({
  required MemoryStudyStore store,
  required _FakeLocalStorageBackend backend,
  required AppController app,
  ImportArchiveStagingService? importStaging,
}) => LocalStorageController(
  store: store,
  backend: backend,
  importStaging: importStaging ?? _MemoryImportStagingService(),
  archiveBuilder: app.exportArchive,
  debounce: const Duration(milliseconds: 5),
);

Future<void> _initialize(
  AppController app,
  LocalStorageController controller,
) async {
  await _waitFor(() => app.state.isHydrated);
  controller.observeAppState(app.state);
  await _waitFor(() => controller.state.initialized);
  controller.observeAppState(app.state);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 400; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before the test timeout.');
}

class _FakeLocalStorageBackend implements LocalStorageBackend {
  _FakeLocalStorageBackend();

  final List<LocalStorageBundle> writes = [];
  final List<LocalStorageLocation> releasedLocations = [];
  final List<String> archivedImports = [];

  @override
  Future<LocalStorageLocation?> pickLocation({
    LocalStorageSettings? current,
  }) async => const LocalStorageLocation(
    locationId: 'picked-local-folder',
    displayName: 'Sprache',
    kind: LocalStorageLocationKind.fileSystemPath,
  );

  @override
  Future<LocalStorageLocation> verifyLocation(
    LocalStorageLocation location,
  ) async => location;

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) async {
    writes.add(bundle);
    return LocalStorageWriteResult(
      savedAt: DateTime.utc(2026, 7, 30, 12, 0, writes.length),
      sha256Hex: bundle.archiveSha256,
      byteLength: bundle.archiveBytes,
    );
  }

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) async =>
      null;

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) async => false;

  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) async {
    archivedImports.add(originalFileName);
    return const LocalImportArchiveResult(
      created: true,
      relativePath: 'imports/fake.xlsx',
    );
  }

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {
    releasedLocations.add(location);
  }
}

class _MemoryImportStagingService implements ImportArchiveStagingService {
  final Map<String, StagedImportArchive> _entries = {};

  @override
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  }) async {
    final staged = StagedImportArchive(
      id: sha256Hex,
      originalFileName: originalFileName,
      sha256Hex: sha256Hex,
      bytes: bytes,
      createdAt: DateTime.utc(2026, 7, 30),
      distributionKey: distributionKey,
    );
    _entries[staged.id] = staged;
    return staged;
  }

  @override
  Future<List<StagedImportArchive>> list() async =>
      List.unmodifiable(_entries.values);

  @override
  Future<void> remove(String id) async {
    _entries.remove(id);
  }
}
