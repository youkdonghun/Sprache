import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/sync/pending_sync.dart';

void main() {
  testWidgets(
    'settings shows persisted upload state and reconnect action after restart',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      final now = DateTime.utc(2026, 7, 28, 10);
      final store = MemoryStudyStore(
        profile: const StoredProfile(
          selectedLanguage: LanguageTag.english,
          totalXp: 40,
          streakDays: 2,
          dailyXp: 10,
          badges: {},
          driveConnected: true,
          progress: {},
        ),
        pendingSnapshotSync: PendingSyncOperation(
          operationId: 'snapshot-persisted',
          entityType: PendingSyncEntityType.snapshot,
          entityId: 'state/snapshot.json',
          payload: const {'schemaVersion': 1},
          attempts: 2,
          nextAttemptAt: now.add(const Duration(seconds: 20)),
          createdAt: now,
        ),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              googleConnectionServiceProvider.overrideWithValue(
                _UnavailableRestoreService(),
              ),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-settings')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('pending-sync-status')), findsOneWidget);
        expect(find.textContaining('동기화 재시도 2회'), findsOneWidget);
        expect(find.text('Google 다시 연결'), findsOneWidget);
        expect(
          find.byKey(const Key('delete-google-account-binding')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets(
    'Railway binding deletion remains available after device disconnect',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      final service = _DeletableRestoreService();
      final store = MemoryStudyStore(
        profile: const StoredProfile(
          selectedLanguage: LanguageTag.english,
          totalXp: 0,
          streakDays: 0,
          dailyXp: 0,
          badges: {},
          driveConnected: true,
          progress: {},
        ),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              googleConnectionServiceProvider.overrideWithValue(service),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-settings')));
        await tester.pumpAndSettle();

        expect(find.text('이 기기에서 연결 해제'), findsOneWidget);
        await tester.tap(find.text('이 기기에서 연결 해제'));
        await tester.pumpAndSettle();

        expect(service.disconnected, isTrue);
        expect(
          find.byKey(const Key('delete-google-account-binding')),
          findsOneWidget,
        );
        expect(find.text('Railway 연결 기록 확인·삭제'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('open-privacy-details')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-privacy-details')));
        await tester.pumpAndSettle();
        expect(find.textContaining('이 기기의 Google 토큰만 삭제'), findsOneWidget);
        expect(find.textContaining('Railway의 계정–폴더 연결은 유지'), findsOneWidget);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();

        final deleteBindingButton = find.byKey(
          const Key('delete-google-account-binding'),
        );
        await tester.ensureVisible(deleteBindingButton);
        await tester.pumpAndSettle();
        await tester.tap(deleteBindingButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('delete-account-binding-dialog')),
          findsOneWidget,
        );
        expect(find.textContaining('Google 계정을 확인한 뒤'), findsOneWidget);
        expect(find.text('확인 후 삭제'), findsOneWidget);

        await tester.tap(find.text('확인 후 삭제'));
        await tester.pumpAndSettle();

        expect(service.deleted, isTrue);
        expect(
          find.text('계정 연결 기록 삭제를 완료했습니다. 로컬 저장 모드는 그대로 유지됩니다.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}

class _UnavailableRestoreService
    implements GoogleConnectionService, RestorableGoogleConnectionService {
  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    throw StateError('Interactive connection is not used in this test.');
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async => null;

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => null;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}

class _DeletableRestoreService
    implements
        GoogleConnectionService,
        RestorableGoogleConnectionService,
        AccountBindingDeletionService {
  bool disconnected = false;
  bool deleted = false;
  Map<String, Object?>? snapshot;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    throw StateError('Interactive connection is not used in this test.');
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    return const GoogleConnectionResult(
      folderId: 'folder-id',
      folderName: 'Sprache test',
      mock: false,
    );
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  Future<void> deleteAccountBinding() async {
    deleted = true;
  }

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    this.snapshot = snapshot;
  }
}
