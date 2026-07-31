import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/global_search.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
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
}
