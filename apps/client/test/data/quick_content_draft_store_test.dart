import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/database/app_database.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quick_content_draft.dart';
import 'package:sprache/src/domain/quick_content_preferences.dart';
import 'package:sprache/src/domain/search_preferences.dart';

void main() {
  test('memory store saves and clears a device-local quick draft', () async {
    final store = MemoryStudyStore();
    final draft = QuickContentDraft(
      subjectId: 'ko-en',
      kind: LearningItemKind.word,
      text: 'draft',
      meanings: const ['초안'],
      acceptedAnswers: const ['작성 중'],
      readings: const {ReadingScheme.hangul: '드래프트'},
      sentenceTokens: const [],
      example: '',
      exampleMeaning: '',
      partOfSpeech: PartOfSpeech.noun,
      group: '복습',
      tags: const ['중요'],
      favorite: true,
      priority: 4,
      updatedAt: DateTime.utc(2026, 8, 2),
    );

    await store.saveQuickContentDraft(draft);
    final restored = await store.loadQuickContentDraft(subjectId: 'ko-en');
    expect(restored?.text, 'draft');
    expect(restored?.favorite, isTrue);
    expect(restored?.readings[ReadingScheme.hangul], '드래프트');

    await store.clearQuickContentDraft(subjectId: 'ko-en');
    expect(await store.loadQuickContentDraft(subjectId: 'ko-en'), isNull);
  });

  test('stores device-local search history and result layout', () async {
    final store = MemoryStudyStore();
    final preferences = const SearchLocalPreferences()
        .rememberGlobal('bonjour')
        .rememberSubject('language:fr', 'state:due')
        .copyWith(
          globalResultLayout: GlobalSearchResultLayout.subject,
          libraryViewMode: LibraryViewMode.compact,
        );

    await store.saveSearchLocalPreferences(preferences);
    final restored = await store.loadSearchLocalPreferences();

    expect(restored.globalRecent, ['bonjour']);
    expect(restored.recentForSubject('language:fr'), ['state:due']);
    expect(restored.globalResultLayout, GlobalSearchResultLayout.subject);
    expect(restored.libraryViewMode, LibraryViewMode.compact);
  });

  test('draft JSON keeps explicit tokens and language reading schemes', () {
    final original = QuickContentDraft(
      subjectId: 'ko-ja',
      kind: LearningItemKind.sentence,
      text: '水を飲む',
      meanings: const ['물을 마신다'],
      acceptedAnswers: const [],
      readings: const {
        ReadingScheme.kana: 'みずをのむ',
        ReadingScheme.romaji: 'mizu o nomu',
      },
      sentenceTokens: const ['水を', '飲む'],
      example: '',
      exampleMeaning: '',
      partOfSpeech: PartOfSpeech.noun,
      group: null,
      tags: const [],
      favorite: false,
      priority: 0,
      updatedAt: DateTime.utc(2026, 8, 2),
    );

    final restored = QuickContentDraft.fromJson(original.toJson());
    expect(restored.sentenceTokens, original.sentenceTokens);
    expect(restored.readings[ReadingScheme.kana], 'みずをのむ');
  });

  test('quick draft round-trips the registration basket', () {
    const item = LearningItem(
      id: 'basket-word',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'compact',
      translations: ['간결한'],
      acceptedAnswers: ['간결한'],
      partOfSpeech: PartOfSpeech.adjective,
      tags: ['ui'],
      capabilities: {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
      },
      source: ContentSource.userCreated,
    );
    final original = QuickContentDraft(
      subjectId: 'language:en',
      kind: LearningItemKind.word,
      text: '',
      meanings: const [],
      acceptedAnswers: const [],
      readings: const {},
      sentenceTokens: const [],
      example: '',
      exampleMeaning: '',
      partOfSpeech: PartOfSpeech.noun,
      group: null,
      tags: const [],
      favorite: false,
      priority: 0,
      updatedAt: DateTime.utc(2026, 8, 3),
      basket: const [QuickContentBasketDraftEntry(item: item, favorite: true)],
    );

    final restored = QuickContentDraft.fromJson(original.toJson());

    expect(restored.hasContent, isTrue);
    expect(restored.basket, hasLength(1));
    expect(restored.basket.single.item.text, 'compact');
    expect(restored.basket.single.item.tags, ['ui']);
    expect(restored.basket.single.favorite, isTrue);
  });

  test('recent quick group stays device-local by subject', () async {
    final store = MemoryStudyStore();
    final preferences = const QuickContentLocalPreferences().rememberGroup(
      subjectId: 'ko-en',
      name: '업무',
      selectedAt: DateTime.utc(2026, 8, 2, 10),
    );

    await store.saveQuickContentLocalPreferences(preferences);
    final restored = await store.loadQuickContentLocalPreferences();

    expect(restored.recentGroupBySubject['ko-en']?.name, '업무');
    expect(
      restored.recentGroupBySubject['ko-en']?.selectedAt,
      DateTime.utc(2026, 8, 2, 10),
    );
  });

  test(
    'clearing subject B keeps subject A registration basket intact',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final subjectA = _quickDraft(
        subjectId: 'language:en',
        text: '',
        basket: [_basketEntry('language:en', 'curveball')],
      );
      final subjectB = _quickDraft(subjectId: 'language:ja', text: '推し');

      try {
        for (final store in <StudyStore>[
          MemoryStudyStore(),
          DriftStudyStore(database),
        ]) {
          await store.saveQuickContentDraft(subjectA);
          await store.saveQuickContentDraft(subjectB);
          await store.clearQuickContentDraft(subjectId: 'language:ja');

          final restoredA = await store.loadQuickContentDraft(
            subjectId: 'language:en',
          );
          expect(restoredA?.basket, hasLength(1));
          expect(restoredA?.basket.single.item.text, 'curveball');
          expect(
            await store.loadQuickContentDraft(subjectId: 'language:ja'),
            isNull,
          );
        }
      } finally {
        await database.close();
      }
    },
  );

  test(
    'Drift migrates the legacy global draft only for its matching subject',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = DriftStudyStore(database);
      final legacy = _quickDraft(subjectId: 'language:en', text: 'legacy');

      try {
        await database
            .into(database.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                key: 'quick_content_draft',
                valueJson: jsonEncode(legacy.toJson()),
                updatedAt: DateTime.utc(2026, 8, 3),
              ),
            );

        expect(
          await store.loadQuickContentDraft(subjectId: 'language:ja'),
          isNull,
        );
        expect(
          (await database.select(database.appSettings).get()).map(
            (row) => row.key,
          ),
          contains('quick_content_draft'),
        );

        final restored = await store.loadQuickContentDraft(
          subjectId: 'language:en',
        );
        expect(restored?.text, 'legacy');
        final keys = (await database.select(database.appSettings).get())
            .map((row) => row.key)
            .toList();
        expect(keys, isNot(contains('quick_content_draft')));
        expect(
          keys.where((key) => key.startsWith('quick_content_draft_v2:')),
          hasLength(1),
        );
      } finally {
        await database.close();
      }
    },
  );
}

QuickContentDraft _quickDraft({
  required String subjectId,
  required String text,
  List<QuickContentBasketDraftEntry> basket = const [],
}) => QuickContentDraft(
  subjectId: subjectId,
  kind: LearningItemKind.word,
  text: text,
  meanings: text.isEmpty ? const [] : const ['meaning'],
  acceptedAnswers: const [],
  readings: const {},
  sentenceTokens: const [],
  example: '',
  exampleMeaning: '',
  partOfSpeech: PartOfSpeech.noun,
  group: null,
  tags: const [],
  favorite: false,
  priority: 0,
  updatedAt: DateTime.utc(2026, 8, 3),
  basket: basket,
);

QuickContentBasketDraftEntry _basketEntry(String subjectId, String text) =>
    QuickContentBasketDraftEntry(
      item: LearningItem(
        id: '$subjectId-$text',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        subjectId: subjectId,
        text: text,
        translations: const ['meaning'],
        acceptedAnswers: const ['meaning'],
        partOfSpeech: PartOfSpeech.noun,
        tags: const ['basket'],
        capabilities: const {
          ExerciseCapability.recognition,
          ExerciseCapability.production,
        },
        source: ContentSource.userCreated,
      ),
      favorite: true,
    );
