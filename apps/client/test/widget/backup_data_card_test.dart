import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/config/app_config.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';

void main() {
  testWidgets('settings exposes backup, restore, Excel, and CSV actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-data-card')),
      500,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.byKey(const Key('backup-data-card')), findsOneWidget);
    expect(find.byKey(const Key('export-backup-json')), findsOneWidget);
    expect(find.byKey(const Key('restore-backup-json')), findsOneWidget);
    expect(find.byKey(const Key('export-content-xlsx')), findsOneWidget);
    expect(find.byKey(const Key('export-content-csv')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings explains Google, Railway, speech, and deletion privacy',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://sprache-api-production.up.railway.app',
                googleAndroidClientId: 'android-client-id',
                googleDesktopClientId: 'desktop-client-id',
                googleServerClientId: 'server-client-id',
                appEnvironment: 'test',
                mockMode: false,
                appVersion: '1.22.7',
                privacyPolicyUrl:
                    'https://sprache-api-production.up.railway.app/privacy',
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1100));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-privacy-details')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-privacy-details')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-details-dialog')), findsOneWidget);
      expect(find.text('Google 계정과 Drive 사용'), findsOneWidget);
      expect(find.text('Railway에 저장하는 정보'), findsOneWidget);
      expect(find.text('발음 연습'), findsOneWidget);
      expect(find.text('삭제와 연결 해제'), findsOneWidget);
      expect(find.textContaining('앱 버전 1.22.7'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-privacy-web')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
