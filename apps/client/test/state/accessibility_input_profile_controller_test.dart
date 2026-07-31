import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/services/local_storage_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';

void main() {
  test('accessibility profile persists across controller recreation', () async {
    final store = MemoryStudyStore();
    var controller = _buildController(store);
    await _waitFor(() => controller.state.initialized);

    const profile = AccessibilityInputProfile(
      largeRatingControls: true,
      cardScale: AccessibilityCardScale.large,
      highContrast: true,
      reduceMotion: true,
      androidSelectionGesture: AndroidSelectionGesture.buttonsOnly,
    );
    await controller.updateAccessibilityInputProfile(profile);

    expect(
      (await store.loadLocalStorageSettings())
          .accessibilityInputProfile
          .highContrast,
      isTrue,
    );
    controller.dispose();

    controller = _buildController(store);
    await _waitFor(() => controller.state.initialized);
    expect(
      controller.state.settings.accessibilityInputProfile.cardScale,
      AccessibilityCardScale.large,
    );
    expect(
      controller.state.settings.accessibilityInputProfile.largeRatingControls,
      isTrue,
    );
    controller.dispose();
  });

  test('device accessibility profile never enters Drive snapshots', () async {
    final store = MemoryStudyStore(
      localStorageSettings: const LocalStorageSettings(
        accessibilityInputProfile: AccessibilityInputProfile(
          highContrast: true,
          reduceMotion: true,
          cardScale: AccessibilityCardScale.extraLarge,
        ),
      ),
    );
    final app = AppController(store);
    await _waitFor(() => app.state.isHydrated);

    final archiveJson = jsonEncode(app.exportArchive());

    expect(archiveJson, isNot(contains('accessibilityInputProfile')));
    expect(archiveJson, isNot(contains('windowsShortcuts')));
    app.dispose();
  });
}

LocalStorageController _buildController(MemoryStudyStore store) {
  return LocalStorageController(
    store: store,
    backend: _UnusedBackend(),
    importStaging: _EmptyStaging(),
    archiveBuilder: () => const {},
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition was not reached');
}

class _EmptyStaging implements ImportArchiveStagingService {
  @override
  Future<List<StagedImportArchive>> list() async => const [];

  @override
  Future<void> remove(String id) async {}

  @override
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  }) {
    throw UnimplementedError();
  }
}

class _UnusedBackend implements LocalStorageBackend {
  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) {
    throw UnimplementedError();
  }

  @override
  Future<LocalStorageLocation?> pickLocation({LocalStorageSettings? current}) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) {
    throw UnimplementedError();
  }

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {}

  @override
  Future<LocalStorageLocation> verifyLocation(LocalStorageLocation location) {
    throw UnimplementedError();
  }

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) {
    throw UnimplementedError();
  }
}
