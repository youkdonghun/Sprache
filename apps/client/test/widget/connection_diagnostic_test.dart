import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/config/app_config.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/desktop_google_oauth.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/integrations/google/google_drive_client.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';

void main() {
  testWidgets(
    'Windows explains loopback and shows the current Google connection step',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final service = _WaitingFolderService();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
              appConfigProvider.overrideWithValue(
                const AppConfig(
                  googleAndroidClientId: '',
                  googleDesktopClientId: 'desktop-client-id',
                  googleServerClientId: '',
                  appEnvironment: 'test',
                  mockMode: false,
                ),
              ),
              googleConnectionServiceProvider.overrideWithValue(service),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('home-settings')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('windows-loopback-note')), findsOneWidget);
        expect(find.textContaining('별도 중계 서버'), findsOneWidget);

        final connectGoogle = find.byKey(const Key('connect-google'));
        await tester.ensureVisible(connectGoogle);
        await tester.pumpAndSettle();
        await tester.tap(connectGoogle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('google-connection-progress')),
          findsOneWidget,
        );
        expect(find.text('2/4 Drive 폴더 선택'), findsOneWidget);
        expect(find.textContaining('127.0.0.1이 보여도 괜찮아요'), findsOneWidget);

        service.complete();
        await tester.pumpAndSettle();
        expect(find.text('연결됨'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('settings can copy an actionable connection diagnostic', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            googleConnectionServiceProvider.overrideWithValue(
              _OAuthFailureService(),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-storage')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('connect-google')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('connect-google')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('connection-diagnostic')), findsOneWidget);
      expect(
        find.text('GOOGLE-TOKEN-EXCHANGE-400-INVALID-CLIENT'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('copy-connection-diagnostic')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(clipboardText, contains('진단 코드: GOOGLE-TOKEN-EXCHANGE'));
      expect(clipboardText, contains('로컬 데이터: 유지됨'));
      expect(find.text('오류 진단 내용을 복사했습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    }
  });

  testWidgets('settings shows recovery steps and a safe quarantine preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(MemoryStudyStore()),
          googleConnectionServiceProvider.overrideWithValue(
            _QuarantinedSnapshotService(),
          ),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-storage')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('connect-google')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('connect-google')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connection-recovery-steps')), findsOneWidget);
    expect(find.byKey(const Key('remote-quarantine-preview')), findsOneWidget);
    expect(
      find.byKey(const Key('remote-quarantine-safe-preview')),
      findsOneWidget,
    );
    expect(find.textContaining('123 bytes'), findsOneWidget);
    expect(find.textContaining('private study content'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _OAuthFailureService implements GoogleConnectionService {
  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    onStage?.call(GoogleConnectionStage.signIn);
    throw const GoogleOAuthException(
      operation: 'Google token exchange',
      statusCode: 400,
      code: 'invalid_client',
      description: 'The OAuth client was not found.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => null;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}

class _WaitingFolderService implements GoogleConnectionService {
  final _result = Completer<GoogleConnectionResult>();
  Map<String, Object?>? snapshot;

  void complete() {
    if (_result.isCompleted) return;
    _result.complete(
      const GoogleConnectionResult(
        folderId: 'folder-id',
        folderName: 'Sprache test',
        mock: false,
      ),
    );
  }

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    onStage?.call(GoogleConnectionStage.signIn);
    onStage?.call(GoogleConnectionStage.folderSelection);
    return _result.future;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    this.snapshot = snapshot;
  }
}

class _QuarantinedSnapshotService implements GoogleConnectionService {
  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'drive-root',
      folderName: 'WordStudyData',
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() {
    return Future.error(
      DriveDataIntegrityException(
        'drive_manifest_sha_mismatch',
        'checksum mismatch: private study content',
        quarantine: DriveQuarantineRecord(
          fileId: 'quarantine-copy',
          fileName: 'snapshot.json.sha-mismatch.copy',
          sourceFileId: 'snapshot-file',
          createdAt: DateTime.utc(2026, 7, 29),
          reasonCode: 'drive_manifest_sha_mismatch',
          preview: 'snapshot.json · 123 bytes · SHA-256 0123456789abcdef…',
        ),
      ),
    );
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}
