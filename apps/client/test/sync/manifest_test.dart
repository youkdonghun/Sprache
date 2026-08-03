import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/sync/sync_models.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27);

  SyncManifest manifest(String revision) => SyncManifest(
    schemaVersion: 1,
    datasetVersion: 1,
    appRootFolderId: 'folder',
    files: {
      'progress': ManifestFile(
        fileId: 'file',
        revision: revision,
        sha256: 'hash-$revision',
        updatedAt: now,
      ),
    },
    updatedAt: now,
  );

  test('detects only changed manifest files', () {
    expect(manifest('2').changedFilesComparedTo(manifest('1')), {'progress'});
    expect(manifest('1').changedFilesComparedTo(manifest('1')), isEmpty);
  });

  test('segmented layout survives a manifest JSON round trip', () {
    final segmented = SyncManifest(
      schemaVersion: 1,
      datasetVersion: 2,
      appRootFolderId: 'folder',
      layout: 'segmented-v1',
      files: manifest('1').files,
      updatedAt: now,
    );

    final restored = SyncManifest.fromJson(segmented.toJson());

    expect(restored.layout, 'segmented-v1');
    expect(restored.datasetVersion, 2);
  });

  test('canonical layout keeps exactly one stable snapshot pointer', () {
    final canonical = SyncManifest(
      schemaVersion: 1,
      datasetVersion: 3,
      appRootFolderId: 'folder',
      layout: 'canonical-v1',
      files: {
        'state/snapshot.json': ManifestFile(
          fileId: 'canonical-file-id',
          revision: '9',
          sha256: List.filled(64, 'a').join(),
          updatedAt: now,
        ),
      },
      updatedAt: now,
    );

    final restored = SyncManifest.fromJson(canonical.toJson());

    expect(restored.layout, 'canonical-v1');
    expect(restored.files.keys, ['state/snapshot.json']);
    expect(restored.files['state/snapshot.json']?.fileId, 'canonical-file-id');
  });
}
