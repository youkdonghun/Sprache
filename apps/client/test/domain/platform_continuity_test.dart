import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/offline_readiness.dart';
import 'package:sprache/src/domain/platform_capabilities.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/inbound_intent.dart';
import 'package:sprache/src/services/media_lifecycle_coordinator.dart';

void main() {
  test('central capability table explains real and preview limitations', () {
    final android = PlatformCapabilityRegistry.forPlatform(
      TargetPlatform.android,
    );
    final apple = PlatformCapabilityRegistry.forPlatform(TargetPlatform.iOS);
    expect(
      android.capability(PlatformFeature.driveSync).fullySupported,
      isTrue,
    );
    expect(apple.capability(PlatformFeature.driveSync).available, isFalse);
    expect(
      apple.capability(PlatformFeature.driveSync).reason,
      contains('Apple 미리보기'),
    );
  });

  test('typed inbound parser accepts allowlisted plans, routes and files', () {
    const parser = InboundIntentParser();
    expect(
      parser.parse('session-plan/my-plan').intent,
      isA<SessionPlanInboundIntent>(),
    );
    expect(
      parser.parse('sprache://route/library').intent,
      isA<RouteInboundIntent>(),
    );
    final file = parser.parse('file:///C:/Study/words.tsv');
    expect(file.intent, isA<ImportFileInboundIntent>());
    expect((file.intent! as ImportFileInboundIntent).extension, 'tsv');
    final windowsLaunch = parser.parseLaunchArgument(r'"C:\Study\words.JSONL"');
    expect(windowsLaunch.intent, isA<ImportFileInboundIntent>());
    expect(
      (windowsLaunch.intent! as ImportFileInboundIntent).extension,
      'jsonl',
    );
  });

  test(
    'typed inbound parser rejects traversal, huge data and unknown routes',
    () {
      const parser = InboundIntentParser();
      expect(
        parser.parse('file:///C:/Study/../secret.csv').error,
        InboundIntentError.unsafePath,
      );
      expect(
        parser.parse('sprache://route/admin').error,
        InboundIntentError.unsupportedRoute,
      );
      expect(
        parser.parse('file:///C:/Study/run.exe').error,
        InboundIntentError.unsupportedFileType,
      );
      expect(
        parser.parse(List.filled(5000, 'x').join()).error,
        InboundIntentError.tooLong,
      );
      expect(
        parser.parse('file:///C:/Study/bad%ZZ.csv').error,
        InboundIntentError.invalidEncoding,
      );
    },
  );

  test(
    'background lifecycle saves checkpoint before stopping all media',
    () async {
      final events = <String>[];
      final coordinator = MediaLifecycleCoordinator(
        persistCheckpoint: () => events.add('checkpoint'),
        stopTextToSpeech: () => events.add('tts'),
        stopSpeechRecognition: () => events.add('speech'),
        stopRecording: () => events.add('recording'),
        stopEffects: () => events.add('effects'),
      );
      final first = coordinator.enterBackground();
      final second = coordinator.enterBackground();
      expect(identical(first, second), isTrue);
      final result = await first;
      expect(result.checkpointSaved, isTrue);
      expect(events, ['checkpoint', 'tts', 'speech', 'recording', 'effects']);
      coordinator.resume();
      await coordinator.enterBackground();
      expect(events.where((value) => value == 'checkpoint'), hasLength(2));
    },
  );

  test('active media registry fans out each lifecycle channel once', () async {
    final events = <String>[];
    final registry = MediaLifecycleRegistry();
    final owner = Object();
    registry.register(
      owner,
      MediaLifecycleRegistration(
        persistCheckpoint: () => events.add('checkpoint'),
        stopTextToSpeech: () => events.add('tts'),
        stopSpeechRecognition: () => events.add('speech'),
        stopRecording: () => events.add('recording'),
        stopEffects: () => events.add('effects'),
      ),
    );
    await registry.persistCheckpoints();
    await registry.stopTextToSpeech();
    await registry.stopSpeechRecognition();
    await registry.stopRecording();
    await registry.stopEffects();
    expect(events, ['checkpoint', 'tts', 'speech', 'recording', 'effects']);

    registry.unregister(owner);
    await registry.stopTextToSpeech();
    expect(events, hasLength(5));
  });

  test('media cleanup continues after one registered owner fails', () async {
    final events = <String>[];
    final registry = MediaLifecycleRegistry();
    registry.register(
      Object(),
      MediaLifecycleRegistration(
        stopRecording: () {
          events.add('failed-owner');
          throw StateError('recorder unavailable');
        },
      ),
    );
    registry.register(
      Object(),
      MediaLifecycleRegistration(
        stopRecording: () => events.add('remaining-owner'),
      ),
    );

    await expectLater(registry.stopRecording(), throwsStateError);
    expect(events, ['failed-owner', 'remaining-owner']);
  });

  test(
    'offline report keeps local study available with graceful fallbacks',
    () {
      final report = const OfflineReadinessBuilder().build(
        databaseReady: true,
        localItemCount: 12,
        offlineTtsAvailable: false,
        speechPackAvailable: false,
        pendingWrites: 3,
      );
      expect(report.canStudy, isTrue);
      expect(
        report.checks.singleWhere((value) => value.id == 'pending').detail,
        contains('3개'),
      );
      final listening = offlinePlanForMode(
        StudyMode.listening,
        ttsAvailable: false,
        speechAvailable: false,
      );
      expect(listening.fallbackMode, StudyMode.meaning);
      expect(listening.level, OfflineReadinessLevel.deviceService);
    },
  );
}
