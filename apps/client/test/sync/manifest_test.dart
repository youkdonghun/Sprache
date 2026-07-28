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
}
