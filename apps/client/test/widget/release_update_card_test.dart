import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/services/release_update_coordinator.dart';
import 'package:sprache/src/services/release_update_installer_contract.dart';
import 'package:sprache/src/services/release_update_service.dart';
import 'package:sprache/src/widgets/release_update_card.dart';

void main() {
  testWidgets('checks only on demand and applies an available update', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReleaseUpdateCard(
            currentVersion: '1.37.1',
            manifestUrl: 'https://sprache6.github.io/app/release.json',
            coordinator: coordinator,
          ),
        ),
      ),
    );

    expect(coordinator.checkCalls, 0);
    expect(find.byKey(const Key('apply-release-update')), findsNothing);

    await tester.tap(find.byKey(const Key('check-release-update')));
    await tester.pumpAndSettle();

    expect(coordinator.checkCalls, 1);
    expect(find.textContaining('업데이트를 사용할 수 있습니다'), findsOneWidget);
    expect(find.byKey(const Key('apply-release-update')), findsOneWidget);

    await tester.tap(find.byKey(const Key('apply-release-update')));
    await tester.pumpAndSettle();

    expect(coordinator.applyCalls, 1);
    expect(find.text('설치 화면을 열었습니다.'), findsOneWidget);
  });
}

class _FakeCoordinator implements ReleaseUpdateCoordinator {
  int checkCalls = 0;
  int applyCalls = 0;

  @override
  String get platformKey => 'windows';

  @override
  Future<ReleaseUpdateCheck> check(String currentVersion) async {
    checkCalls += 1;
    return ReleaseUpdateCheck(
      currentVersion: ReleaseVersion.tryParse(currentVersion)!,
      manifest: _manifest,
      platform: platformKey,
      updateAvailable: true,
    );
  }

  @override
  Future<ReleaseInstallResult> apply(
    ReleaseUpdateCheck check, {
    required ReleaseDownloadProgress onProgress,
  }) async {
    applyCalls += 1;
    onProgress(50, 100);
    return const ReleaseInstallResult(message: '설치 화면을 열었습니다.');
  }
}

final _manifest = ReleaseManifest.fromJson(<String, Object?>{
  'schemaVersion': 1,
  'version': '1.38.0',
  'buildNumber': 68,
  'publishedAt': '2026-09-02T00:00:00Z',
  'title': 'Sprache 1.38.0',
  'notes': <String>['앱 안에서 업데이트를 확인할 수 있습니다.'],
  'releasePageUrl':
      'https://github.com/youkdonghun/Sprache/releases/tag/v1.38.0',
  'artifacts': <String, Object?>{
    'windows': <String, Object?>{
      'kind': 'installer',
      'url':
          'https://github.com/youkdonghun/Sprache/releases/download/v1.38.0/Sprache-Windows-Setup-1.38.0-google-x64.exe',
      'fileName': 'Sprache-Windows-Setup-1.38.0-google-x64.exe',
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'sizeBytes': 1024,
    },
  },
});
