import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/course_picker.dart';

void main() {
  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets(
      'subject editor fits ${size.width.toInt()}px with the full symbol palette',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                studyStoreProvider.overrideWithValue(MemoryStudyStore()),
              ],
              child: const SpracheApp(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('shell-mobile-subject-switcher')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('create-study-subject-from-shell-picker')),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('study-subject-symbol-categories')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('save-study-subject')), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
        }
      },
    );
  }

  testWidgets('creates and selects a general study subject from the picker', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(padding: EdgeInsets.all(24), child: CoursePicker()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-study-subject')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('study-subject-name')),
        '산업안전기사',
      );
      await tester.enterText(
        find.byKey(const Key('study-subject-description')),
        '시험 핵심 개념과 법규',
      );
      await tester.tap(
        find.byKey(const Key('study-subject-symbol-category-sports')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('study-subject-symbol-option-야구')));
      await tester.pump();
      final symbolField = tester.widget<TextFormField>(
        find.byKey(const Key('study-subject-symbol')),
      );
      expect(symbolField.controller?.text, '야구');
      await tester.tap(find.byKey(const Key('save-study-subject')));
      await tester.pumpAndSettle();

      final controller = container.read(appControllerProvider.notifier);
      expect(controller.activeSubject.name, '산업안전기사');
      expect(controller.activeSubject.symbol, '야구');
      expect(controller.activeSubject.isLanguage, isFalse);
      expect(controller.state.activeSubjectId, startsWith('general:topic-'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('edits, hides, and restores a built-in language subject', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: CoursePicker()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-study-subject-language:en')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('edit-study-subject-action-language:en')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('study-subject-name')),
      '업무 영어',
    );
    await tester.enterText(find.byKey(const Key('study-subject-symbol')), '업');
    await tester.tap(find.byKey(const Key('save-study-subject')));
    await tester.pumpAndSettle();

    final controller = container.read(appControllerProvider.notifier);
    expect(controller.activeSubject.name, '업무 영어');

    await tester.tap(find.byKey(const Key('edit-study-subject-language:en')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delete-study-subject-action-language:en')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-hide-study-subject')));
    await tester.pumpAndSettle();

    expect(
      controller.availableSubjects.map((subject) => subject.id),
      isNot(contains('language:en')),
    );
    expect(controller.hiddenSubjects.single.name, '업무 영어');

    final hiddenSubjectsCard = find.byKey(
      const Key('restore-hidden-study-subjects'),
    );
    await tester.ensureVisible(hiddenSubjectsCard);
    await tester.pumpAndSettle();
    await tester.tap(hiddenSubjectsCard);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('restore-study-subject-language:en')),
    );
    await tester.pumpAndSettle();

    expect(controller.activeSubject.id, 'language:en');
    expect(controller.activeSubject.name, '업무 영어');
    expect(tester.takeException(), isNull);
  });

  testWidgets('many study subjects support horizontal drag and arrow paging', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(520, 180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final customSubjects = [
        for (var index = 0; index < 14; index++)
          StudySubject(
            id: 'general:topic-$index',
            kind: StudySubjectKind.general,
            name: '사용자 주제 ${index + 1}',
            description: '가로 탐색 검증용 주제',
            symbol: index.isEven ? '📚' : '🎯',
            contentLanguage: LanguageTag.korean,
          ),
      ];
      final container = ProviderContainer(
        overrides: [
          studyStoreProvider.overrideWithValue(
            MemoryStudyStore(
              preferences: StudyPreferences(
                activeSubjectId: 'language:en',
                customSubjects: customSubjects,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(padding: EdgeInsets.all(16), child: CoursePicker()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      IconButton pagingButton(Key key) => tester.widget<IconButton>(
        find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
      );
      final createButton = find.byKey(const Key('create-study-subject'));
      final createButtonCenter = tester.getCenter(createButton);
      final subjectListTop = tester.getTopLeft(
        find.byKey(const Key('study-subject-list')),
      );

      expect(
        pagingButton(const Key('study-subject-scroll-previous')).onPressed,
        isNull,
      );
      expect(
        pagingButton(const Key('study-subject-scroll-next')).onPressed,
        isNotNull,
      );
      expect(tester.getSize(createButton), const Size.square(48));
      expect(createButtonCenter.dy, lessThan(subjectListTop.dy));
      expect(
        find.descendant(
          of: find.byKey(const Key('study-subject-list')),
          matching: createButton,
        ),
        findsNothing,
      );

      await tester.drag(
        find.byKey(const Key('study-subject-list')),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();
      expect(
        pagingButton(const Key('study-subject-scroll-previous')).onPressed,
        isNotNull,
      );

      for (var page = 0; page < 12; page++) {
        final next = pagingButton(const Key('study-subject-scroll-next'));
        if (next.onPressed == null) break;
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('study-subject-scroll-next')),
            matching: find.byType(IconButton),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('study-subject-general:topic-13')),
        findsOneWidget,
      );
      expect(tester.getCenter(createButton), createButtonCenter);
      expect(createButton, findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shell subject picker exposes an independent create action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const Key('open-shell-subject-picker'),
                  onPressed: () => showSubjectPicker(context),
                  child: const Text('주제 선택'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-shell-subject-picker')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('create-study-subject-from-shell-picker')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('create-study-subject-from-shell-picker')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('study-subject-name')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('study-subject-name')),
      '분리된 새 주제',
    );
    await tester.tap(find.byKey(const Key('save-study-subject')));
    await tester.pumpAndSettle();

    expect(
      container.read(appControllerProvider.notifier).activeSubject.name,
      '분리된 새 주제',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundled baseball pack creates a subject and opens review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ImportScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('load-baseball-starter-pack')));
    await tester.pump();
    expect(find.byKey(const Key('import-busy-progress')), findsOneWidget);
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byKey(const Key('import-commit-button')).evaluate().isNotEmpty) {
        break;
      }
    }

    final controller = container.read(appControllerProvider.notifier);
    expect(controller.activeSubject.id, 'general:baseball');
    expect(controller.activeSubject.name, '야구 용어');
    expect(find.text('baseball-starter-pack-2026-07-28.json'), findsWidgets);
    expect(find.textContaining('WHIP'), findsWidgets);
    expect(find.byKey(const Key('import-commit-button')), findsOneWidget);
  });
}
