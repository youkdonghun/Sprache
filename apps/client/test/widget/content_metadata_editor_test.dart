import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('editor saves and displays word provenance metadata', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    final store = MemoryStudyStore();

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
      await tester.tap(find.byKey(const Key('library-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-full-editor')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item-text-field')),
        'record',
      );
      await tester.enterText(
        find.byKey(const Key('item-translation-field')),
        '기록하다',
      );
      await tester.enterText(
        find.byKey(const Key('item-korean-pronunciation-field')),
        '리코드',
      );
      await tester.tap(find.byKey(const Key('item-part-of-speech-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동사').last);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('item-editor-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-source-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('item-source-section')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('item-source-name-field')),
        '업무 영어 노트',
      );
      await tester.enterText(
        find.byKey(const Key('item-license-field')),
        'private',
      );
      await tester.enterText(
        find.byKey(const Key('item-source-version-field')),
        '2026.2',
      );
      await tester.enterText(
        find.byKey(const Key('item-source-id-field')),
        'entry-42',
      );
      await tester.enterText(
        find.byKey(const Key('item-source-author-field')),
        '업무 영어 팀',
      );
      await tester.enterText(
        find.byKey(const Key('item-source-url-field')),
        'https://example.com/entry-42',
      );
      await tester.enterText(
        find.byKey(const Key('item-attribution-field')),
        '업무 영어 팀 · 업무 영어 노트 · private',
      );

      tester.testTextInput.hide();
      await tester.drag(
        find.byKey(const Key('item-editor-scroll')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('item-editor-scroll')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('추가하기'), findsOneWidget);
      await tester.tap(find.text('추가하기'));
      await tester.pumpAndSettle();

      final saved = store.savedItems.single;
      expect(saved.partOfSpeech, PartOfSpeech.verb);
      expect(saved.reading(ReadingScheme.hangul), '리코드');
      expect(saved.source.name, '업무 영어 노트');
      expect(saved.source.license, 'private');
      expect(saved.source.sourceVersion, '2026.2');
      expect(saved.source.contentVersion, 1);
      expect(saved.source.sourceId, 'entry-42');
      expect(saved.source.sourceUrl, 'https://example.com/entry-42');
      expect(saved.source.author, '업무 영어 팀');
      expect(saved.source.attribution, '업무 영어 팀 · 업무 영어 노트 · private');

      await tester.tap(find.text('record').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-source-metadata')), findsOneWidget);
      expect(find.text('동사'), findsWidgets);
      expect(find.text('리코드'), findsOneWidget);
      expect(find.text('업무 영어 노트'), findsOneWidget);
      expect(find.text('출처 2026.2 · 콘텐츠 v1'), findsOneWidget);
      expect(find.text('entry-42'), findsOneWidget);
      expect(find.text('업무 영어 팀'), findsOneWidget);
      expect(find.text('업무 영어 팀 · 업무 영어 노트 · private'), findsOneWidget);
      expect(find.byKey(const Key('item-source-url-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('editor explains invalid Japanese reading formats before save', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    final store = MemoryStudyStore(
      profile: const StoredProfile(
        selectedLanguage: LanguageTag.japanese,
        totalXp: 0,
        streakDays: 0,
        dailyXp: 0,
        badges: {},
        driveConnected: false,
        progress: {},
      ),
      preferences: const StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:ja',
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
      await tester.tap(find.byKey(const Key('library-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-full-editor')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('item-text-field')), '水');
      await tester.enterText(
        find.byKey(const Key('item-translation-field')),
        '물',
      );
      await tester.enterText(
        find.byKey(const Key('item-reading-field')),
        'mizu',
      );
      await tester.enterText(
        find.byKey(const Key('item-secondary-reading-field')),
        'みず',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('히라가나·가타카나'), findsOneWidget);
      expect(find.textContaining('라틴 문자와 장음 부호'), findsOneWidget);
      expect(store.savedItems, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('editor protects unsaved input before leaving', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-full-editor')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item-text-field')),
        'unfinished',
      );
      await tester.tap(find.byKey(const Key('item-editor-back-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('item-editor-unsaved-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('item-editor-keep-editing')));
      await tester.pumpAndSettle();
      expect(find.text('unfinished'), findsOneWidget);
      expect(find.byKey(const Key('item-text-field')), findsOneWidget);

      await tester.tap(find.text('오늘').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('item-editor-unsaved-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('item-editor-keep-editing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-text-field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('item-editor-back-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('item-editor-discard-and-exit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library-add-button')), findsOneWidget);
      expect(find.byKey(const Key('item-text-field')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
