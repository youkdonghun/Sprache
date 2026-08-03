import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/backup_archive.dart';
import 'package:sprache/src/domain/dataset_capacity.dart';
import 'package:sprache/src/import/import_limits.dart';

void main() {
  test('import, sync, and backup share one dataset capacity contract', () {
    const limits = ImportLimits();

    expect(limits.maxGeneratedItems, DatasetCapacityPolicy.maxCustomItems);
    expect(limits.maxDatasetItems, DatasetCapacityPolicy.maxCustomItems);
    expect(
      BackupArchiveCodec.maxArchiveBytes,
      DatasetCapacityPolicy.maxBackupArchiveBytes,
    );
  });

  test('dataset capacity is checked before an import can be committed', () {
    const limits = ImportLimits(maxDatasetItems: 2);

    limits.ensureDatasetItemCount(2);
    expect(
      () => limits.ensureDatasetItemCount(3),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.message,
          'message',
          contains('저장 후 사용자 자료'),
        ),
      ),
    );
  });
}
