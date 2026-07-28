import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/state/app_state.dart';
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
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-settings')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('pending-sync-status')), findsOneWidget);
        expect(find.textContaining('동기화 재시도 2회'), findsOneWidget);
        expect(find.text('Google 다시 연결'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}
