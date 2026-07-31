import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app_bootstrap.dart';
import 'package:sprache/src/data/database/database_bootstrap.dart';
import 'package:sprache/src/screens/database_recovery_screen.dart';

void main() {
  testWidgets('recovery mode fits mobile and exposes only safe actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    var exports = 0;
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DatabaseRecoveryScreen(
          diagnostic: _diagnostic(),
          onExport: () async {
            exports++;
            return '저장 완료';
          },
          onRetry: () async {
            retries++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('읽기 전용 복구 모드'), findsOneWidget);
    expect(find.textContaining('쓰거나 초기화하지 않습니다'), findsOneWidget);
    expect(find.byKey(const Key('database-preserved-status')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('export-database-recovery')));
    await tester.pumpAndSettle();
    expect(exports, 1);
    expect(find.text('저장 완료'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry-database-open')));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bootstrap gate shows recovery instead of the normal app', (
    tester,
  ) async {
    final bootstrapper = _RecoveryBootstrapper(_diagnostic());

    await tester.pumpWidget(SpracheBootstrap(bootstrapper: bootstrapper));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('database-recovery-title')), findsOneWidget);
    expect(find.text('학습 콘텐츠 가져오기'), findsNothing);
    expect(bootstrapper.openCount, 1);
  });
}

DatabaseRecoveryDiagnostic _diagnostic() => DatabaseRecoveryDiagnostic(
  code: DatabaseRecoveryCode.migrationFailed,
  summary: '업그레이드 전 데이터 사본을 보존했습니다.',
  expectedSchemaVersion: 2,
  detectedSchemaVersion: 1,
  databaseByteLength: 1024 * 1024,
  databaseModifiedAt: DateTime.utc(2026, 7, 29, 2),
  preservedFiles: const [
    PreservedDatabaseFile(
      path: 'C:/safe/sprache.sqlite',
      archiveName: 'sprache.sqlite',
      byteLength: 1024 * 1024,
      sha256: 'safe-sha256',
    ),
  ],
  preservedAt: DateTime.utc(2026, 7, 29, 3),
  technicalSummary: 'SqliteException: migration rolled back',
);

class _RecoveryBootstrapper implements DatabaseBootstrapper {
  _RecoveryBootstrapper(this.diagnostic);

  final DatabaseRecoveryDiagnostic diagnostic;
  int openCount = 0;

  @override
  Future<DatabaseBootstrapResult> open() async {
    openCount++;
    return DatabaseRecoveryRequired(diagnostic);
  }

  @override
  Future<Uint8List> createRecoveryArchive(
    DatabaseRecoveryDiagnostic diagnostic,
  ) async {
    return Uint8List.fromList([1, 2, 3]);
  }
}
