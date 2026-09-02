import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/global_search.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_subject.dart';

void main() {
  final english = StudySubject.language(LanguageTag.english);
  final french = StudySubject.language(LanguageTag.french);
  final items = [
    const LearningItem(
      id: 'english-cafe',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'café',
      translations: ['카페'],
      acceptedAnswers: ['카페'],
      example: 'Meet me at the café.',
    ),
    const LearningItem(
      id: 'french-greeting',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.french,
      text: 'bonjour',
      translations: ['안녕하세요'],
      acceptedAnswers: ['안녕하세요'],
      readings: [Reading(scheme: ReadingScheme.hangul, value: '봉주르')],
    ),
  ];

  test('searches every visible subject with NFKC and accent folding', () {
    final results = searchAcrossSubjects(
      query: 'cafe',
      subjects: [english, french],
      items: items,
    );

    expect(results, hasLength(1));
    expect((results.single as GlobalItemSearchResult).item.id, 'english-cafe');
  });

  test('finds a cross-subject item by Korean reading alias', () {
    final results = searchAcrossSubjects(
      query: '봉주르',
      subjects: [english, french],
      items: items,
    );

    final item = results.whereType<GlobalItemSearchResult>().single;
    expect(item.subject.id, languageSubjectId(LanguageTag.french));
    expect(item.item.text, 'bonjour');
  });

  test('requires every token and ranks primary text above metadata', () {
    final results = searchAcrossSubjects(
      query: 'bonjour 안녕',
      subjects: [english, french],
      items: items,
    );

    expect(results.whereType<GlobalItemSearchResult>(), hasLength(1));
    expect(results.first, isA<GlobalItemSearchResult>());
  });

  test('applies local type and learning-state operators across subjects', () {
    final results = searchAcrossSubjects(
      query: 'type:word state:favorite state:due',
      subjects: [english, french],
      items: items,
      favoriteItemIds: {'french-greeting'},
      progressById: {
        'french-greeting': ProgressRecord(
          itemId: 'french-greeting',
          correctCount: 1,
          status: LearningStatus.review,
          nextReviewAt: DateTime.utc(2026, 8, 1),
        ),
      },
      now: DateTime.utc(2026, 8, 3),
    );

    expect(results.whereType<GlobalSubjectSearchResult>(), isEmpty);
    expect(
      results.whereType<GlobalItemSearchResult>().single.item.id,
      'french-greeting',
    );
  });

  test(
    'cooperative search yields and matches the synchronous result',
    () async {
      var eventLoopProgressed = false;
      Future<void>.delayed(Duration.zero, () => eventLoopProgressed = true);

      final cooperative = searchAcrossSubjectsCooperatively(
        query: '봉주르',
        subjects: [english, french],
        items: List<LearningItem>.generate(
          600,
          (index) => index == 599
              ? items.last
              : LearningItem(
                  id: 'filler-$index',
                  kind: LearningItemKind.word,
                  learningLanguage: LanguageTag.english,
                  text: 'filler $index',
                  translations: ['채움 $index'],
                  acceptedAnswers: ['채움 $index'],
                ),
        ),
        yieldEvery: 40,
      );

      await Future<void>.delayed(Duration.zero);
      expect(eventLoopProgressed, isTrue);
      final results = await cooperative;
      expect(results.whereType<GlobalItemSearchResult>(), hasLength(1));
      expect(
        results.whereType<GlobalItemSearchResult>().single.item.id,
        'french-greeting',
      );
    },
  );

  test('cooperative search stops obsolete work', () async {
    var cancelled = false;
    Future<void>.delayed(Duration.zero, () => cancelled = true);

    final results = await searchAcrossSubjectsCooperatively(
      query: 'filler',
      subjects: [english],
      items: List<LearningItem>.generate(
        600,
        (index) => LearningItem(
          id: 'cancel-$index',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'filler $index',
          translations: const ['채움'],
          acceptedAnswers: const ['채움'],
        ),
      ),
      yieldEvery: 40,
      isCancelled: () => cancelled,
    );

    expect(results, isEmpty);
  });
}
