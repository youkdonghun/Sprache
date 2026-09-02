import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('a recent session can exclude final correct items', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final items = sampleContent
        .where((item) => item.learningLanguage == LanguageTag.english)
        .take(3)
        .toList(growable: false);
    final store = MemoryStudyStore();
    await store.saveStudySession(
      StudySessionSummary(
        sessionId: 'reusable-session',
        courseId: 'ko-en',
        startedAt: DateTime.utc(2026, 7, 28, 9),
        endedAt: DateTime.utc(2026, 7, 28, 9, 5),
        correctCount: 2,
        wrongCount: 1,
        earnedXp: 25,
        itemIds: items.map((item) => item.id).toList(growable: false),
        wrongItemIds: {items.last.id},
        finalCorrectItemIds: {items.first.id, items[1].id},
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
      await tester.tap(find.text('기록').last);
      await tester.pumpAndSettle();
      final actions = find.byKey(
        const Key('recent-session-actions-reusable-session'),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(actions);
      await tester.pumpAndSettle();
      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('맞힌 항목 빼고 풀기'));
      await tester.pumpAndSettle();

      expect(store.savedPreferences.sessionPlan.selectedItemIds, {
        items.last.id,
      });
      expect(find.byKey(const Key('session-subject-key')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
