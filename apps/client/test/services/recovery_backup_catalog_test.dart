import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/services/recovery_backup_catalog.dart';

void main() {
  test('only recovery folders older than 30 days become eligible', () async {
    final root = await Directory.systemTemp.createTemp(
      'sprache-recovery-catalog-',
    );
    addTearDown(() => root.delete(recursive: true));
    final old = await _backup(
      root,
      'old-backup',
      DateTime.utc(2026, 7, 1),
      120,
    );
    final recent = await _backup(
      root,
      'recent-backup',
      DateTime.utc(2026, 8, 20),
      80,
    );
    final service = RecoveryBackupCatalogService(
      rootResolver: () async => root.path,
      clock: () => DateTime.utc(2026, 9),
    );

    final inventory = await service.inspect();

    expect(inventory.items, hasLength(2));
    expect(inventory.eligibleCount, 1);
    expect(inventory.eligibleBytes, 120);
    expect(
      inventory.items
          .singleWhere((item) => item.id == 'old-backup')
          .eligibleForCleanup,
      isTrue,
    );
    expect(
      inventory.items
          .singleWhere((item) => item.id == 'recent-backup')
          .eligibleForCleanup,
      isFalse,
    );

    final result = await service.deleteSelected(
      inventory: inventory,
      selectedIds: {'old-backup'},
    );
    expect(result.deletedCount, 1);
    expect(result.deletedBytes, 120);
    expect(await old.exists(), isFalse);
    expect(await recent.exists(), isTrue);
  });

  test(
    'changed recovery folder is never deleted from a stale inventory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sprache-recovery-catalog-stale-',
      );
      addTearDown(() => root.delete(recursive: true));
      final backup = await _backup(
        root,
        'old-backup',
        DateTime.utc(2026, 7, 1),
        120,
      );
      final service = RecoveryBackupCatalogService(
        rootResolver: () async => root.path,
        clock: () => DateTime.utc(2026, 9),
      );
      final inventory = await service.inspect();
      final changed = File(
        '${backup.path}${Platform.pathSeparator}changed.sqlite-wal',
      );
      await changed.writeAsBytes(List<int>.filled(20, 1));
      await changed.setLastModified(DateTime.utc(2026, 7, 1));

      await expectLater(
        service.deleteSelected(
          inventory: inventory,
          selectedIds: {'old-backup'},
        ),
        throwsStateError,
      );
      expect(await backup.exists(), isTrue);
    },
  );
}

Future<Directory> _backup(
  Directory root,
  String name,
  DateTime modifiedAt,
  int bytes,
) async {
  final directory = Directory('${root.path}${Platform.pathSeparator}$name');
  await directory.create();
  final file = File('${directory.path}${Platform.pathSeparator}sprache.sqlite');
  await file.writeAsBytes(List<int>.filled(bytes, 1));
  await file.setLastModified(modifiedAt);
  return directory;
}
