import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

const _existing = LearningItem(
  id: 'existing-water',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: 'water',
  translations: ['물'],
  acceptedAnswers: ['물'],
  partOfSpeech: PartOfSpeech.noun,
  tags: ['기초'],
);

const _preview = ImportPreview(
  entries: [
    ParsedImportEntry(
      row: 2,
      item: LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물', '생수'],
        acceptedAnswers: ['물', '생수'],
        partOfSpeech: PartOfSpeech.noun,
        tags: ['기초', '생활'],
      ),
    ),
    ParsedImportEntry(
      row: 3,
      item: LearningItem(
        id: 'new-axolotl',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'axolotl',
        translations: ['우파루파'],
        acceptedAnswers: ['우파루파'],
        partOfSpeech: PartOfSpeech.noun,
        tags: ['동물'],
      ),
    ),
  ],
  issues: [ImportIssue(row: 5, message: 'meaning 값이 필요합니다.')],
  duplicates: [
    ImportDuplicate(
      row: 4,
      firstRow: 3,
      item: LearningItem(
        id: 'duplicate-axolotl',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'axolotl',
        translations: ['우파루파'],
        acceptedAnswers: ['우파루파'],
        partOfSpeech: PartOfSpeech.noun,
      ),
      kind: ImportDuplicateKind.semantic,
    ),
  ],
);

final _previousImport = ImportCommitRecord(
  importId: 'previous-import',
  fileName: 'study-review.csv',
  sha256: 'review-file-hash',
  importedRows: 8,
  rejectedRows: 1,
  importedAt: DateTime.utc(2026, 7, 27, 9, 15),
);

void main() {
  testWidgets('mobile import source picker stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpSourcePicker(tester, dark: false);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-import-source-picker.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile dark import source picker stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpSourcePicker(tester, dark: true);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-import-source-picker-dark.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile import review stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpReview(tester, dark: false);
      await tester.drag(find.byType(ListView).first, const Offset(0, -780));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-import-review.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile dark import review stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpReview(tester, dark: true);
      await tester.drag(find.byType(ListView).first, const Offset(0, -780));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-import-review-dark.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop import review stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    try {
      await _pumpReview(tester, dark: false);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-import-review.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}

Future<void> _pumpSourcePicker(
  WidgetTester tester, {
  required bool dark,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.mobile,
        darkTheme: AppTheme.mobileDark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: ImportScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpReview(WidgetTester tester, {required bool dark}) async {
  final store = MemoryStudyStore();
  await store.saveCustomItems(const [_existing]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: defaultTargetPlatform == TargetPlatform.android
            ? AppTheme.mobile
            : AppTheme.desktop,
        darkTheme: defaultTargetPlatform == TargetPlatform.android
            ? AppTheme.mobileDark
            : AppTheme.desktopDark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: ImportScreen(
            initialPreview: _preview,
            initialFileName: 'study-review.csv',
            initialSha256: 'review-file-hash',
            initialPreviousImport: _previousImport,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
