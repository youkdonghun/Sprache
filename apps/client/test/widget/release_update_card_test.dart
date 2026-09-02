import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/services/release_link_share_service.dart';
import 'package:sprache/src/services/release_update_coordinator.dart';
import 'package:sprache/src/services/release_update_installer_contract.dart';
import 'package:sprache/src/services/release_update_service.dart';
import 'package:sprache/src/widgets/release_update_card.dart';
import 'package:sprache/src/widgets/startup_release_update_prompt.dart';

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

  testWidgets('offers the current Android APK again after checking', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator(
      platformKey: 'android',
      updateAvailable: false,
    );
    final sharing = _FakeLinkShareService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReleaseUpdateCard(
            currentVersion: '1.38.0',
            currentBuildNumber: 68,
            manifestUrl:
                'https://github.com/youkdonghun/Sprache/releases/latest/download/release.json',
            coordinator: coordinator,
            linkShareService: sharing,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('check-release-update')));
    await tester.pumpAndSettle();

    expect(find.text('최신 APK 다시 받기'), findsOneWidget);
    expect(find.text('최신 APK 링크 공유'), findsOneWidget);
    expect(find.textContaining('APK를 다시 받을 수 있습니다'), findsOneWidget);

    await tester.tap(find.byKey(const Key('apply-release-update')));
    await tester.pumpAndSettle();

    expect(coordinator.applyCalls, 1);

    await tester.tap(find.byKey(const Key('share-latest-apk-link')));
    await tester.pumpAndSettle();

    expect(sharing.calls, 1);
    expect(find.text('최신 APK 링크를 공유했습니다.'), findsOneWidget);
  });

  testWidgets('checks once at startup and only prompts for a newer release', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator(platformKey: 'android');
    final sharing = _FakeLinkShareService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StartupReleaseUpdatePrompt(
            currentVersion: '1.37.1',
            currentBuildNumber: 67,
            manifestUrl:
                'https://github.com/youkdonghun/Sprache/releases/latest/download/release.json',
            coordinator: coordinator,
            linkShareService: sharing,
            child: const SizedBox(key: Key('startup-child')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coordinator.checkCalls, 1);
    expect(
      find.byKey(const Key('startup-release-update-prompt')),
      findsOneWidget,
    );
    expect(find.text('새 버전 1.38.0이 있어요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-startup-apk-link')));
    await tester.pumpAndSettle();
    expect(sharing.calls, 1);

    await tester.tap(find.byKey(const Key('dismiss-startup-update')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('startup-release-update-prompt')),
      findsNothing,
    );
    expect(find.byKey(const Key('startup-child')), findsOneWidget);
  });

  testWidgets('stays silent at startup when the installed version is current', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator(
      platformKey: 'android',
      updateAvailable: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StartupReleaseUpdatePrompt(
          currentVersion: '1.38.0',
          currentBuildNumber: 68,
          manifestUrl:
              'https://github.com/youkdonghun/Sprache/releases/latest/download/release.json',
          coordinator: coordinator,
          child: const SizedBox(key: Key('startup-current-child')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coordinator.checkCalls, 1);
    expect(
      find.byKey(const Key('startup-release-update-prompt')),
      findsNothing,
    );
    expect(find.byKey(const Key('startup-current-child')), findsOneWidget);
  });

  testWidgets('startup update prompt fits a 320 pixel wide phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final coordinator = _FakeCoordinator(platformKey: 'android');

    await tester.pumpWidget(
      MaterialApp(
        home: StartupReleaseUpdatePrompt(
          currentVersion: '1.37.1',
          currentBuildNumber: 67,
          manifestUrl:
              'https://github.com/youkdonghun/Sprache/releases/latest/download/release.json',
          coordinator: coordinator,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('startup-release-update-prompt')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeLinkShareService implements ReleaseLinkShareService {
  int calls = 0;

  @override
  Future<void> shareLatestAndroidApk({
    required ReleaseManifest manifest,
    Rect? origin,
  }) async {
    calls += 1;
  }
}

class _FakeCoordinator implements ReleaseUpdateCoordinator {
  _FakeCoordinator({this.platformKey = 'windows', this.updateAvailable = true});

  int checkCalls = 0;
  int applyCalls = 0;

  @override
  final String platformKey;

  final bool updateAvailable;

  @override
  Future<ReleaseUpdateCheck> check(
    String currentVersion, {
    int currentBuildNumber = 0,
  }) async {
    checkCalls += 1;
    return ReleaseUpdateCheck(
      currentVersion: ReleaseVersion.tryParse(currentVersion)!,
      manifest: _manifest,
      platform: platformKey,
      currentBuildNumber: currentBuildNumber,
      updateAvailable: updateAvailable,
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
    'android': <String, Object?>{
      'kind': 'apk',
      'url':
          'https://github.com/youkdonghun/Sprache/releases/download/v1.38.0/Sprache-Android-1.38.0-google-debug-signed.apk',
      'fileName': 'Sprache-Android-1.38.0-google-debug-signed.apk',
      'sha256':
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'sizeBytes': 2048,
    },
  },
});
