import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/screens/storage_maintenance_dialog.dart';
import 'package:sprache/src/services/recovery_backup_catalog.dart';

void main() {
  testWidgets('storage cleanup requires selection and explicit confirmation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);
    final catalog = _FakeRecoveryCatalog();
    String? restoredId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorageMaintenanceDialog(
            localCatalog: catalog,
            onRestoreLocal: (backup) async => restoredId = backup.id,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('자동 삭제하지 않습니다. 30일 보존 기간이 지난 항목만 직접 선택할 수 있습니다.'),
      findsOneWidget,
    );
    expect(find.textContaining('Drive 연결 후'), findsOneWidget);
    final checkboxes = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checkboxes, hasLength(2));
    expect(checkboxes.where((tile) => tile.onChanged == null), hasLength(1));
    expect(find.text('대량 가져오기 전 안전 지점'), findsOneWidget);
    expect(find.textContaining('2026.07.01'), findsOneWidget);
    expect(find.textContaining('항목 7개'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore-checkpoint-old-backup')));
    await tester.pump();
    expect(restoredId, 'old-backup');

    await tester.tap(find.text('대량 가져오기 전 안전 지점'));
    await tester.pump();
    await tester.tap(find.text('선택 영구 삭제'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('로컬 복구 사본을 삭제할까요?'), findsOneWidget);
    expect(catalog.deletedIds, isEmpty);

    await tester.tap(find.text('영구 삭제'));
    await tester.pump();
    await tester.pump();

    expect(catalog.deletedIds, {'old-backup'});
    expect(find.text('recent-backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRecoveryCatalog extends RecoveryBackupCatalogService {
  final deletedIds = <String>{};

  @override
  Future<LocalRecoveryInventory> inspect({
    Duration minimumAge = const Duration(days: 30),
  }) async {
    final items = <LocalRecoveryBackup>[
      if (!deletedIds.contains('old-backup'))
        LocalRecoveryBackup(
          id: 'old-backup',
          path: r'C:\recovery\old-backup',
          byteLength: 64,
          modifiedAt: DateTime.utc(2026, 7, 1),
          fileCount: 1,
          eligibleForCleanup: true,
          reason: 'bulkImport',
          sha256Hex: List.filled(64, 'a').join(),
          itemCount: 7,
          verified: true,
        ),
      LocalRecoveryBackup(
        id: 'recent-backup',
        path: r'C:\recovery\recent-backup',
        byteLength: 64,
        modifiedAt: DateTime.utc(2026, 8, 20),
        fileCount: 1,
        eligibleForCleanup: false,
      ),
    ];
    return LocalRecoveryInventory(
      items: items,
      minimumAge: minimumAge,
      inspectedAt: DateTime.utc(2026, 9),
    );
  }

  @override
  Future<LocalRecoveryCleanupResult> deleteSelected({
    required LocalRecoveryInventory inventory,
    required Set<String> selectedIds,
  }) async {
    deletedIds.addAll(selectedIds);
    return LocalRecoveryCleanupResult(
      deletedCount: selectedIds.length,
      deletedBytes: selectedIds.length * 64,
    );
  }
}
