import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';

void main() {
  testWidgets('backgrounding a connected app flushes a sync snapshot', (
    tester,
  ) async {
    final service = _CountingGoogleService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(MemoryStudyStore()),
          googleConnectionServiceProvider.overrideWithValue(service),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );

    await container.read(connectionControllerProvider.notifier).connect();
    expect(service.pullCount, 1);
    expect(service.pushCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();

    expect(service.pullCount, 2);
    expect(service.pushCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}

class _CountingGoogleService implements GoogleConnectionService {
  Map<String, Object?>? snapshot;
  int pullCount = 0;
  int pushCount = 0;

  @override
  Future<GoogleConnectionResult> connect() async {
    return const GoogleConnectionResult(
      folderId: 'lifecycle-folder',
      folderName: 'Lifecycle Drive',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async {
    pullCount++;
    return snapshot;
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    pushCount++;
    this.snapshot = snapshot;
  }
}
