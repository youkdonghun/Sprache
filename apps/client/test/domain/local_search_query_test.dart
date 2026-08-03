import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/local_search_query.dart';
import 'package:sprache/src/domain/progress.dart';

void main() {
  const item = LearningItem(
    id: 'travel-cafe',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.french,
    text: 'Café',
    translations: ['카페'],
    acceptedAnswers: ['카페'],
    tags: ['여행', 'group:파리 출장'],
  );

  test('parses quoted tag/type/state/group operators and remaining text', () {
    final query = LocalSearchQuery.parse(
      'cafe tag:여행 type:word state:favorite group:"파리 출장"',
    );

    expect(query.textTokens, ['cafe']);
    expect(query.tags, [foldLocalSearchText('여행')]);
    expect(query.types, {LocalSearchItemType.word});
    expect(query.states, {LocalSearchLearningState.favorite});
    expect(query.groups, [foldLocalSearchText('파리 출장')]);
  });

  test('operators combine locally with progress and favorites', () {
    final progress = ProgressRecord(
      itemId: item.id,
      correctCount: 1,
      wrongCount: 2,
      status: LearningStatus.review,
      nextReviewAt: DateTime.utc(2026, 8, 1),
      lastResult: ReviewRating.again,
    );
    expect(
      localSearchItemMatches(
        query: LocalSearchQuery.parse(
          'tag:여행 type:word state:favorite state:due group:"파리 출장"',
        ),
        item: item,
        progress: progress,
        favorite: true,
        now: DateTime.utc(2026, 8, 3),
      ),
      isTrue,
    );
    expect(
      localSearchItemMatches(
        query: LocalSearchQuery.parse('state:mastered'),
        item: item,
        progress: progress,
      ),
      isFalse,
    );
  });

  test('highlight ranges preserve original accented text positions', () {
    final ranges = searchHighlightRanges('Meet at Café today', 'cafe');

    expect(ranges, hasLength(1));
    expect(
      'Meet at Café today'.substring(ranges.single.start, ranges.single.end),
      'Café',
    );
  });

  test(
    'similar search suggestions use local edit distance and stay bounded',
    () {
      final suggestions = suggestSimilarSearches(
        query: 'bonjor',
        candidates: ['hello', 'bonjour', 'bonsoir', 'bonjour', 'goodbye'],
        limit: 3,
      );

      expect(suggestions.first, 'bonjour');
      expect(suggestions.where((value) => value == 'bonjour'), hasLength(1));
      expect(suggestions.length, lessThanOrEqualTo(3));
    },
  );
}
