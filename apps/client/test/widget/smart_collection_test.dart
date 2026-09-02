import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('recent wrong answers form an automatic reusable collection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final item = sampleContent.firstWhere(
      (item) => item.learningLanguage == LanguageTag.english,
    );
    final store = MemoryStudyStore(
      profile: StoredProfile(
        selectedLanguage: LanguageTag.english,
        totalXp: 5,
        streakDays: 1,
        dailyXp: 5,
        badges: const {},
        driveConnected: false,
        progress: {
          item.id: ProgressRecord(
            itemId: item.id,
            wrongCount: 1,
            lastResult: ReviewRating.again,
            lastStudiedAt: DateTime.utc(2026, 7, 28, 10),
          ),
        },
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
      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('smart-learning-collections')),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoiceChip, '오답 1'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('smart-wrong-collection')),
      );
      await tester.tap(find.byKey(const Key('smart-wrong-collection')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('start-smart-collection-compact')),
      );
      await tester.tap(find.byKey(const Key('start-smart-collection-compact')));
      await tester.pumpAndSettle();

      expect(store.savedPreferences.sessionPlan.title, '최근 오답 복습');
      expect(store.savedPreferences.sessionPlan.selectedItemIds, {item.id});
      expect(find.byKey(const Key('session-subject-key')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
