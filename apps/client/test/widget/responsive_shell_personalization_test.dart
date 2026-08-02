import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  Future<void> verifyWindowsShell(
    WidgetTester tester,
    AppExperiencePreferences experience,
    Future<void> Function() verify,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                preferences: StudyPreferences(
                  onboardingCompleted: true,
                  activeSubjectId: 'language:en',
                  experience: experience,
                ),
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await verify();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  }

  Finder visibleNavigationLabel(String routeName, String label) {
    return find.descendant(
      of: find.byKey(Key('nav-$routeName')),
      matching: find.text(label),
    );
  }

  testWidgets('selected mode shows only the selected desktop label', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(
        navigationLabelMode: AppNavigationLabelMode.selected,
      ),
      () async {
        final semantics = tester.ensureSemantics();
        try {
          expect(visibleNavigationLabel('home', '오늘'), findsOneWidget);
          expect(visibleNavigationLabel('learn', '학습'), findsNothing);
          expect(visibleNavigationLabel('library', '자료실'), findsNothing);
          expect(visibleNavigationLabel('stats', '기록'), findsNothing);
          expect(visibleNavigationLabel('settings', '설정'), findsNothing);
          expect(
            tester.getSemantics(find.byKey(const Key('nav-home'))).label,
            contains('현재 위치'),
          );
          expect(
            tester.getSemantics(find.byKey(const Key('nav-learn'))).label,
            contains('학습 탭'),
          );

          await tester.tap(find.byKey(const Key('nav-learn')));
          await tester.pumpAndSettle();

          expect(visibleNavigationLabel('home', '오늘'), findsNothing);
          expect(visibleNavigationLabel('learn', '학습'), findsOneWidget);
          expect(
            tester.getSemantics(find.byKey(const Key('nav-learn'))).label,
            contains('현재 위치'),
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  });

  testWidgets('icons-only mode collapses the desktop sidebar', (tester) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(
        navigationLabelMode: AppNavigationLabelMode.iconsOnly,
      ),
      () async {
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester.getSize(find.byKey(const Key('desktop-sidebar'))).width,
            78,
          );
          expect(visibleNavigationLabel('home', '오늘'), findsNothing);
          expect(visibleNavigationLabel('learn', '학습'), findsNothing);
          expect(
            tester.getSemantics(find.byKey(const Key('nav-home'))).label,
            contains('오늘 탭'),
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  });

  testWidgets('compact subject switcher is symbol-only on desktop', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(
        subjectSwitcherStyle: AppSubjectSwitcherStyle.compact,
      ),
      () async {
        final switcher = find.byKey(const Key('shell-subject-switcher'));
        expect(
          find.descendant(of: switcher, matching: find.text('EN')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: switcher, matching: find.text('영어')),
          findsNothing,
        );
        expect(
          find.descendant(of: switcher, matching: find.byType(Text)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('hidden sync status removes its desktop status copy', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(showSyncStatus: false),
      () async {
        final switcher = find.byKey(const Key('shell-subject-switcher'));
        final copy = tester
            .widgetList<Text>(
              find.descendant(of: switcher, matching: find.byType(Text)),
            )
            .map((widget) => widget.data)
            .whereType<String>()
            .toList();
        expect(copy, ['영어']);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'global search and quick-add chrome can be hidden independently',
    (tester) async {
      await verifyWindowsShell(
        tester,
        const AppExperiencePreferences(
          showGlobalSearch: false,
          showQuickAdd: false,
        ),
        () async {
          expect(find.byKey(const Key('open-global-search')), findsNothing);
          expect(find.byKey(const Key('shell-quick-add')), findsNothing);
          expect(find.byKey(const Key('open-keyboard-help')), findsOneWidget);
          expect(find.byKey(const Key('nav-home')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets('focused content width caps the desktop main pane at 880', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(contentWidth: AppContentWidth.focused),
      () async {
        final widthBox = find.byKey(const Key('shell-main-content-width'));
        expect(
          tester.widget<ConstrainedBox>(widthBox).constraints.maxWidth,
          880,
        );
        expect(tester.getSize(widthBox).width, 880);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('wide content width exposes its 1360 desktop maximum', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(contentWidth: AppContentWidth.wide),
      () async {
        final widthBox = find.byKey(const Key('shell-main-content-width'));
        expect(
          tester.widget<ConstrainedBox>(widthBox).constraints.maxWidth,
          1360,
        );
        expect(tester.getSize(widthBox).width, greaterThan(880));
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('balanced defaults keep the established desktop layout', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(),
      () async {
        expect(
          tester.getSize(find.byKey(const Key('desktop-sidebar'))).width,
          226,
        );
        expect(find.byKey(const Key('shell-main-content-width')), findsNothing);
        expect(visibleNavigationLabel('home', '오늘'), findsOneWidget);
        expect(visibleNavigationLabel('learn', '학습'), findsOneWidget);
        expect(visibleNavigationLabel('library', '자료실'), findsOneWidget);
        expect(visibleNavigationLabel('stats', '기록'), findsOneWidget);
        expect(visibleNavigationLabel('settings', '설정'), findsOneWidget);

        final switcher = find.byKey(const Key('shell-subject-switcher'));
        expect(
          find.descendant(of: switcher, matching: find.text('영어')),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<Text>(
                find.descendant(of: switcher, matching: find.byType(Text)),
              )
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('navigation icon styles reach desktop destinations', (
    tester,
  ) async {
    await verifyWindowsShell(
      tester,
      const AppExperiencePreferences(
        navigationIconStyle: AppNavigationIconStyle.outlined,
      ),
      () async {
        final homeIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('nav-home')),
            matching: find.byType(Icon),
          ),
        );
        final learnIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('nav-learn')),
            matching: find.byType(Icon),
          ),
        );
        expect(homeIcon.icon, Icons.home_outlined);
        expect(learnIcon.icon, Icons.school_outlined);
      },
    );
  });
}
