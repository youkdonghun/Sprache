import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quick_content_draft.dart';
import 'package:sprache/src/domain/quick_content_preferences.dart';

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
    final restored = await store.loadQuickContentDraft();
    expect(restored?.text, 'draft');
    expect(restored?.favorite, isTrue);
    expect(restored?.readings[ReadingScheme.hangul], '드래프트');

    await store.clearQuickContentDraft();
    expect(await store.loadQuickContentDraft(), isNull);
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
}
