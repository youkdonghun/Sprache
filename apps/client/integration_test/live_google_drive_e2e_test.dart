import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/config/app_config.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart' hide ConnectionState;

const _runLiveGoogleE2e = bool.fromEnvironment('RUN_LIVE_GOOGLE_E2E');
const _markerId = 'live-e2e-windows-android-marker-v1';
const _markerGroup = '기기 간 동기화 검증';
const _markerSubjectId = 'general:device-sync';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows connects to Google Drive and uploads a cross-device marker',
    skip: !_runLiveGoogleE2e,
    timeout: const Timeout(Duration(minutes: 25)),
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          googleConnectionServiceProvider.overrideWith((ref) {
            return DesktopGoogleConnectionService(
              config: ref.read(appConfigProvider),
              tokenVault: ref.read(tokenVaultProvider),
              urlLauncher: _launchChrome,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SpracheApp(),
        ),
      );
      await _waitFor(
        tester,
        () => container.read(appControllerProvider).isHydrated,
        timeout: const Duration(seconds: 30),
        failureMessage: '로컬 학습 데이터 초기화가 끝나지 않았습니다.',
      );

      final config = container.read(appConfigProvider);
      _expectLiveWindowsConfig(config);

      await container
          .read(connectionControllerProvider.notifier)
          .connect()
          .timeout(const Duration(minutes: 22));
      await tester.pump();

      final connected = container.read(connectionControllerProvider);
      if (connected.phase == ConnectionPhase.failed) {
        fail(
          connected.diagnostic?.clipboardText ??
              'Google·Drive 연결에 실패했지만 진단 정보가 없습니다.',
        );
      }
      expect(connected.phase, ConnectionPhase.connected);
      expect(container.read(appControllerProvider).driveConnected, isTrue);
      expect(connected.folderName, isNotEmpty);

      final app = container.read(appControllerProvider.notifier);
      await app.upsertStudySubject(
        StudySubject(
          id: _markerSubjectId,
          kind: StudySubjectKind.general,
          name: '기기 간 동기화',
          description: 'Windows에서 만들고 Android에서 복원하는 실계정 검증 주제',
          symbol: '🔄',
          contentLanguage: LanguageTag.english,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await app.upsertCustomItem(_crossDeviceMarker());
      await app.organizeItemsInLearningGroup(
        const [_markerId],
        _markerGroup,
        copy: true,
      );
      await container
          .read(connectionControllerProvider.notifier)
          .syncNow()
          .timeout(const Duration(minutes: 2));
      await tester.pump();

      final synced = container.read(connectionControllerProvider);
      if (synced.phase == ConnectionPhase.failed) {
        fail(
          synced.diagnostic?.clipboardText ?? 'Drive 업로드에 실패했지만 진단 정보가 없습니다.',
        );
      }
      expect(synced.phase, ConnectionPhase.connected);
      expect(synced.lastSyncedAt, isNotNull);
      expect(container.read(appControllerProvider).pendingSync, isNull);
      expect(app.customItemById(_markerId), isNotNull);
      expect(app.activeSubject.id, _markerSubjectId);
      expect(
        app.itemsForLearningGroup(_markerGroup).map((item) => item.id),
        contains(_markerId),
      );
    },
  );
}

Future<bool> _launchChrome(Uri authorizationUri) async {
  final environment = Platform.environment;
  final candidates = [
    if (environment['LOCALAPPDATA'] case final localAppData?)
      '$localAppData\\Google\\Chrome\\Application\\chrome.exe',
    if (environment['ProgramFiles'] case final programFiles?)
      '$programFiles\\Google\\Chrome\\Application\\chrome.exe',
    if (environment['ProgramFiles(x86)'] case final programFilesX86?)
      '$programFilesX86\\Google\\Chrome\\Application\\chrome.exe',
  ];
  String? chromePath;
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      chromePath = candidate;
      break;
    }
  }
  if (chromePath == null) {
    throw StateError(
      'Chrome 실행 파일을 찾을 수 없습니다. 확인한 경로: ${candidates.join(', ')}',
    );
  }
  stdout.writeln('SPRACHE_LIVE_OAUTH_URL=$authorizationUri');
  await Process.start(chromePath, [
    authorizationUri.toString(),
  ], mode: ProcessStartMode.detached);
  return true;
}

void _expectLiveWindowsConfig(AppConfig config) {
  expect(config.mockMode, isFalse);
  expect(config.appEnvironment, 'production');
  expect(config.apiBaseUrl, startsWith('https://'));
  expect(config.googleDesktopClientId, isNotEmpty);
}

LearningItem _crossDeviceMarker() {
  return LearningItem(
    id: _markerId,
    kind: LearningItemKind.sentence,
    subjectId: _markerSubjectId,
    learningLanguage: LanguageTag.english,
    text: 'Windows and Android stay in sync.',
    translations: const ['Windows와 Android는 동기화됩니다.'],
    acceptedAnswers: const ['Windows와 Android는 동기화됩니다.'],
    sentenceTokens: const ['Windows', 'and', 'Android', 'stay', 'in', 'sync.'],
    tags: const ['실계정 검증', 'Windows 생성'],
    level: '입문',
    capabilities: const {
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.cloze,
      ExerciseCapability.listening,
      ExerciseCapability.sentenceOrder,
    },
    priority: 5,
    source: const ContentSource(
      name: 'Sprache live Google E2E',
      license: 'private',
      sourceVersion: '1',
      contentVersion: 1,
      sourceId: _markerId,
      attribution: '실제 Windows→Drive→Android 동기화 확인용 사용자 비공개 문장',
    ),
    updatedAt: DateTime.now().toUtc(),
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String failureMessage,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail(failureMessage);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
  }
}
