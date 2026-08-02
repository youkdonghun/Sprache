import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/library_search.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/smart_collection.dart';

void main() {
  const cafe = LearningItem(
    id: 'cafe',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.french,
    text: 'Café',
    translations: ['카페'],
    acceptedAnswers: ['카페'],
    partOfSpeech: PartOfSpeech.noun,
    tags: ['여행'],
    source: ContentSource(
      name: '개인 단어장',
      license: 'private',
      sourceVersion: '1',
      contentVersion: 1,
    ),
  );
  const fullWidth = LearningItem(
    id: 'full',
    kind: LearningItemKind.sentence,
    learningLanguage: LanguageTag.japanese,
    text: 'ＡＢＣ',
    translations: ['알파벳'],
    acceptedAnswers: ['알파벳'],
  );

  test('search folds width, accents, spacing and searches every token', () {
    expect(foldLibrarySearchText('  ＣＡＦÉ  '), 'cafe');
    expect(
      libraryItemMatches(
        item: cafe,
        progress: null,
        criteria: const LibrarySearchCriteria(query: 'cafe 여행'),
        now: DateTime.utc(2026, 7, 31),
      ),
      isTrue,
    );
    expect(
      libraryItemMatches(
        item: fullWidth,
        progress: null,
        criteria: const LibrarySearchCriteria(query: 'abc'),
        now: DateTime.utc(2026, 7, 31),
      ),
      isTrue,
    );
  });

  test('facets combine with due state and stable sort', () {
    final progress = {
      cafe.id: ProgressRecord(
        itemId: cafe.id,
        correctCount: 1,
        wrongCount: 2,
        status: LearningStatus.review,
        nextReviewAt: DateTime.utc(2026, 7, 30),
      ),
      fullWidth.id: ProgressRecord(
        itemId: fullWidth.id,
        correctCount: 3,
        status: LearningStatus.mastered,
        nextReviewAt: DateTime.utc(2026, 8, 2),
      ),
    };
    final result = filterAndSortLibraryItems(
      items: const [fullWidth, cafe],
      progressById: progress,
      criteria: const LibrarySearchCriteria(
        kinds: {LearningItemKind.word},
        partsOfSpeech: {PartOfSpeech.noun},
        tags: {'여행'},
        sources: {'개인 단어장'},
        learningState: LibraryLearningStateFilter.due,
      ),
      now: DateTime.utc(2026, 7, 31),
    );
    expect(result, [cafe]);
  });

  test('equal sort values preserve catalog order', () {
    final result = filterAndSortLibraryItems(
      items: const [fullWidth, cafe],
      progressById: const {},
      criteria: const LibrarySearchCriteria(
        sortOrder: LibrarySortOrder.recentlyStudied,
      ),
      now: DateTime.utc(2026, 7, 31),
    );
    expect(result, const [fullWidth, cafe]);
  });

  test('inline tag, type, state and group operators combine', () {
    final groupedCafe = cafe.copyWith(tags: const ['여행', 'group:파리 출장']);
    final result = filterAndSortLibraryItems(
      items: [groupedCafe, fullWidth],
      progressById: {
        cafe.id: ProgressRecord(
          itemId: cafe.id,
          correctCount: 1,
          wrongCount: 1,
          status: LearningStatus.review,
          nextReviewAt: DateTime.utc(2026, 7, 30),
        ),
      },
      favoriteItemIds: {cafe.id},
      criteria: const LibrarySearchCriteria(
        query: 'tag:여행 type:word state:favorite state:due group:"파리 출장"',
      ),
      now: DateTime.utc(2026, 7, 31),
    );

    expect(result.map((item) => item.id), [cafe.id]);
  });

  test('smart collection definition round-trips', () {
    final definition = SmartCollectionDefinition(
      id: 'smart-1',
      subjectId: 'language:fr',
      name: '여행 명사',
      query: 'cafe',
      kinds: const {LearningItemKind.word},
      tags: const {'여행'},
      sort: SmartCollectionSort.alphabetical,
      updatedAt: DateTime.utc(2026, 7, 31),
      pinned: true,
    );
    final criteria = LibrarySearchCriteriaSmartCollection.fromSmartCollection(
      definition,
    );
    final rebuilt = criteria.toSmartCollection(
      id: definition.id,
      subjectId: definition.subjectId,
      name: definition.name,
      updatedAt: definition.updatedAt,
      pinned: definition.pinned,
    );
    expect(rebuilt.id, definition.id);
    expect(criteria.tags, {'여행'});
    expect(criteria.kinds, {LearningItemKind.word});
    expect(criteria.sortOrder, LibrarySortOrder.alphabetical);
    expect(rebuilt.pinned, isTrue);
  });
}
