import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  testWidgets(
    'study announces state, honors remapped controls, and fixes focus order',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 820);
      final semantics = tester.ensureSemantics();
      final profile = const AccessibilityInputProfile(reduceTransparency: true)
          .remapShortcut(StudyShortcutAction.showHint, StudyShortcutKey.keyR)
          .remapShortcut(StudyShortcutAction.dontKnow, StudyShortcutKey.keyD)
          .remapShortcut(StudyShortcutAction.skip, StudyShortcutKey.keyS)
          .remapShortcut(StudyShortcutAction.pause, StudyShortcutKey.keyA);
      const experience = AppExperiencePreferences(
        celebrationLevel: AppCelebrationLevel.off,
      );
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(
          onboardingCompleted: true,
          experience: experience,
          interaction: StudyInteractionPreferences(
            choiceLayout: StudyChoiceLayout.list,
            shuffleChoices: false,
          ),
        ),
        localStorageSettings: LocalStorageSettings(
          accessibilityInputProfile: profile,
        ),
      );
      final controller = AppController(store);

      try {
        for (var attempt = 0; attempt < 20; attempt++) {
          if (controller.state.isHydrated) break;
          await tester.pump();
        }
        expect(controller.state.isHydrated, isTrue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              appControllerProvider.overrideWith((ref) => controller),
              accessibilityInputProfileProvider.overrideWithValue(profile),
            ],
            child: MaterialApp(
              theme: AppTheme.desktopFor(
                experience,
                brightness: Brightness.light,
                accessibilityProfile: profile,
              ),
              home: const StudyScreen(mode: StudyMode.meaning, itemLimit: 2),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final question = tester.widget<Semantics>(
          find.byKey(const Key('study-question-live-region')),
        );
        expect(question.properties.liveRegion, isTrue);
        expect(question.properties.label, contains('문제 1/2'));
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'study-question',
        );

        final shortcutHost = tester.widget<CallbackShortcuts>(
          find.byKey(const Key('study-screen')),
        );
        final assignedKeys = shortcutHost.bindings.keys
            .whereType<SingleActivator>()
            .map((activator) => activator.trigger)
            .toSet();
        expect(
          assignedKeys,
          containsAll(const [
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.keyD,
            LogicalKeyboardKey.keyS,
            LogicalKeyboardKey.keyA,
          ]),
        );

        final firstPrompt = tester
            .widget<Text>(find.byKey(const Key('study-question-prompt')))
            .data;
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.pump();
        expect(
          tester
              .widget<Text>(find.byKey(const Key('study-question-prompt')))
              .data,
          isNot(firstPrompt),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.pump();
        expect(find.byKey(const Key('study-hint-card')), findsOneWidget);
        final hintLiveRegion = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .singleWhere(
              (widget) =>
                  widget.properties.liveRegion == true &&
                  (widget.properties.label ?? '').startsWith('힌트 1단계'),
            );
        expect(hintLiveRegion.properties.label, isNotEmpty);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('study-feedback-popup')), findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'study-feedback',
        );
        final feedbackLiveRegion = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .singleWhere(
              (widget) =>
                  widget.properties.liveRegion == true &&
                  (widget.properties.label ?? '').contains('오답 결과'),
            );
        expect(feedbackLiveRegion.properties.label, contains('오답 결과'));

        final popup = tester.widget<Material>(
          find.byKey(const Key('study-feedback-popup')),
        );
        expect(popup.elevation, 0);
        expect(find.byKey(const Key('feedback-result-icon')), findsOneWidget);
        final resultDecoration = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const Key('study-feedback-result')),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (resultDecoration.decoration as BoxDecoration).border,
          isNotNull,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('study-feedback-popup')), findsNothing);
        expect(
          tester
              .widget<Semantics>(
                find.byKey(const Key('study-question-live-region')),
              )
              .properties
              .label,
          contains('문제 2/'),
        );
        for (var attempt = 0; attempt < 20; attempt++) {
          if (find
              .byKey(const Key('study-completion-live-region'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
          final next = find.byKey(const Key('next-question-from-feedback'));
          if (next.evaluate().isNotEmpty) {
            await tester.tap(next);
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
          }
          await tester.pumpAndSettle();
        }

        final completion = tester.widget<Semantics>(
          find.byKey(const Key('study-completion-live-region')),
        );
        expect(completion.properties.liveRegion, isTrue);
        expect(completion.properties.label, contains('학습 완료'));
        expect(completion.properties.label, contains('저장'));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}
