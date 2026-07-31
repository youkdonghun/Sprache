import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/database_bootstrap.dart';
import 'package:sprache/src/screens/database_recovery_screen.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  testWidgets('mobile database recovery stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpRecovery(tester, dark: true);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-database-recovery-dark.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop database recovery stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 760);
    try {
      await _pumpRecovery(tester, dark: false);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-database-recovery.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}

Future<void> _pumpRecovery(WidgetTester tester, {required bool dark}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: defaultTargetPlatform == TargetPlatform.android
          ? AppTheme.mobile
          : AppTheme.desktop,
      darkTheme: defaultTargetPlatform == TargetPlatform.android
          ? AppTheme.mobileDark
          : AppTheme.desktopDark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: DatabaseRecoveryScreen(
        diagnostic: DatabaseRecoveryDiagnostic(
          code: DatabaseRecoveryCode.migrationFailed,
          summary: '업그레이드 전 데이터 사본을 보존했으며 일부 변경도 적용하지 않았습니다.',
          expectedSchemaVersion: 2,
          detectedSchemaVersion: 1,
          databaseByteLength: 1283400,
          databaseModifiedAt: DateTime.utc(2026, 7, 29, 2, 30),
          preservedFiles: const [
            PreservedDatabaseFile(
              path: 'C:/safe/sprache.sqlite',
              archiveName: 'sprache.sqlite',
              byteLength: 1283400,
              sha256: 'safe-sha256',
            ),
          ],
          preservedAt: DateTime.utc(2026, 7, 29, 3),
          technicalSummary:
              'SqliteException: migration transaction was rolled back',
        ),
        onExport: () async => '저장 완료',
        onRetry: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}
