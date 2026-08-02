import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/device_preferences.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/privacy_mode_scope.dart';

void main() {
  testWidgets('immediate device curtain covers content until resume', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      devicePreferences: const DevicePreferences(
        privacy: DevicePrivacyPreferences(
          curtainDelay: PrivacyCurtainDelay.immediate,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy-curtain')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('privacy-curtain')), findsNothing);
  });

  testWidgets('privacy scope redacts content but keeps numerical context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyModeScope(
          enabled: true,
          child: Builder(
            builder: (context) => Column(
              children: [
                Text(PrivacyModeScope.redact(context, 'secret word')),
                const Text('정확도 82%'),
                const FilledButton(onPressed: null, child: Text('복습 시작')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('secret word'), findsNothing);
    expect(find.text('••••••'), findsOneWidget);
    expect(find.text('정확도 82%'), findsOneWidget);
    expect(find.text('복습 시작'), findsOneWidget);
  });
}
