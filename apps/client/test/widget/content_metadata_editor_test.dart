import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/learning_item.dart';
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

      await tester.tap(find.text('단어장').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('직접 추가'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item-text-field')),
        'record',
      );
      await tester.enterText(
        find.byKey(const Key('item-translation-field')),
        '기록하다',
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
      expect(saved.source.name, '업무 영어 노트');
      expect(saved.source.license, 'private');
      expect(saved.source.sourceVersion, '2026.2');
      expect(saved.source.contentVersion, 1);

      await tester.tap(find.text('record').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-source-metadata')), findsOneWidget);
      expect(find.text('동사'), findsWidgets);
      expect(find.text('업무 영어 노트'), findsOneWidget);
      expect(find.text('출처 2026.2 · 콘텐츠 v1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
