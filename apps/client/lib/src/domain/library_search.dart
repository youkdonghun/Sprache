import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'learning_item.dart';
import 'progress.dart';
import 'smart_collection.dart';

enum LibraryLearningStateFilter {
  all,
  unstudied,
  due,
  learning,
  mastered,
  suspended,
}

extension LibraryLearningStateFilterLabel on LibraryLearningStateFilter {
  String get koreanLabel => switch (this) {
    LibraryLearningStateFilter.all => '학습 상태 전체',
    LibraryLearningStateFilter.unstudied => '아직 학습 안 함',
    LibraryLearningStateFilter.due => '복습 예정',
    LibraryLearningStateFilter.learning => '학습 중',
    LibraryLearningStateFilter.mastered => '완료',
    LibraryLearningStateFilter.suspended => '잠시 제외',
  };
}

enum LibrarySortOrder {
  catalog,
  alphabetical,
  recentlyStudied,
  lowestAccuracy,
  nextReview,
}

extension LibrarySortOrderLabel on LibrarySortOrder {
  String get koreanLabel => switch (this) {
    LibrarySortOrder.catalog => '기본 순서',
    LibrarySortOrder.alphabetical => '가나다·ABC 순',
    LibrarySortOrder.recentlyStudied => '최근 학습 순',
    LibrarySortOrder.lowestAccuracy => '정확도 낮은 순',
    LibrarySortOrder.nextReview => '복습 임박 순',
  };
}

/// Search and facet state shared by the library and saved smart collections.
///
/// Structural filters such as a learning group remain outside this object so a
/// saved collection cannot accidentally cross a subject boundary.
class LibrarySearchCriteria {
  const LibrarySearchCriteria({
    this.query = '',
    this.kinds = const {},
    this.partsOfSpeech = const {},
    this.tags = const {},
    this.sources = const {},
    this.learningState = LibraryLearningStateFilter.all,
    this.sortOrder = LibrarySortOrder.catalog,
  });

  final String query;
  final Set<LearningItemKind> kinds;
  final Set<PartOfSpeech> partsOfSpeech;
  final Set<String> tags;
  final Set<String> sources;
  final LibraryLearningStateFilter learningState;
  final LibrarySortOrder sortOrder;

  bool get hasFacets =>
      kinds.isNotEmpty ||
      partsOfSpeech.isNotEmpty ||
      tags.isNotEmpty ||
      sources.isNotEmpty ||
      learningState != LibraryLearningStateFilter.all;

  int get facetCount =>
      (kinds.isEmpty ? 0 : 1) +
      (partsOfSpeech.isEmpty ? 0 : 1) +
      (tags.isEmpty ? 0 : 1) +
      (sources.isEmpty ? 0 : 1) +
      (learningState == LibraryLearningStateFilter.all ? 0 : 1);

  LibrarySearchCriteria copyWith({
    String? query,
    Set<LearningItemKind>? kinds,
    Set<PartOfSpeech>? partsOfSpeech,
    Set<String>? tags,
    Set<String>? sources,
    LibraryLearningStateFilter? learningState,
    LibrarySortOrder? sortOrder,
  }) => LibrarySearchCriteria(
    query: query ?? this.query,
    kinds: kinds ?? this.kinds,
    partsOfSpeech: partsOfSpeech ?? this.partsOfSpeech,
    tags: tags ?? this.tags,
    sources: sources ?? this.sources,
    learningState: learningState ?? this.learningState,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, Object?> toJson() => {
    if (query.trim().isNotEmpty) 'query': query.trim(),
    if (kinds.isNotEmpty) 'kinds': kinds.map((value) => value.name).toList(),
    if (partsOfSpeech.isNotEmpty)
      'partsOfSpeech': partsOfSpeech.map((value) => value.name).toList(),
    if (tags.isNotEmpty) 'tags': tags.toList()..sort(),
    if (sources.isNotEmpty) 'sources': sources.toList()..sort(),
    'learningState': learningState.name,
    'sortOrder': sortOrder.name,
  };

  factory LibrarySearchCriteria.fromJson(Map<String, Object?> json) {
    Set<T> enumSet<T extends Enum>(Object? raw, List<T> values, String field) {
      if (raw == null) return {};
      if (raw is! List || raw.any((value) => value is! String)) {
        throw FormatException('$field 값은 문자열 배열이어야 합니다.');
      }
      return {
        for (final name in raw.cast<String>())
          values.firstWhere(
            (value) => value.name == name,
            orElse: () =>
                throw FormatException('$field에 지원하지 않는 값이 있습니다: $name'),
          ),
      };
    }

    Set<String> stringSet(Object? raw, String field) {
      if (raw == null) return {};
      if (raw is! List || raw.any((value) => value is! String)) {
        throw FormatException('$field 값은 문자열 배열이어야 합니다.');
      }
      return raw
          .cast<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    }

    T enumValue<T extends Enum>(
      Object? raw,
      List<T> values,
      T fallback,
      String field,
    ) {
      if (raw == null) return fallback;
      if (raw is! String) {
        throw FormatException('$field 값은 문자열이어야 합니다.');
      }
      return values.firstWhere(
        (value) => value.name == raw,
        orElse: () => throw FormatException('$field에 지원하지 않는 값이 있습니다: $raw'),
      );
    }

    final rawQuery = json['query'];
    if (rawQuery != null && rawQuery is! String) {
      throw const FormatException('query 값은 문자열이어야 합니다.');
    }
    return LibrarySearchCriteria(
      query: (rawQuery as String?) ?? '',
      kinds: enumSet(json['kinds'], LearningItemKind.values, 'kinds'),
      partsOfSpeech: enumSet(
        json['partsOfSpeech'],
        PartOfSpeech.values,
        'partsOfSpeech',
      ),
      tags: stringSet(json['tags'], 'tags'),
      sources: stringSet(json['sources'], 'sources'),
      learningState: enumValue(
        json['learningState'],
        LibraryLearningStateFilter.values,
        LibraryLearningStateFilter.all,
        'learningState',
      ),
      sortOrder: enumValue(
        json['sortOrder'],
        LibrarySortOrder.values,
        LibrarySortOrder.catalog,
        'sortOrder',
      ),
    );
  }
}

extension LibrarySearchCriteriaSmartCollection on LibrarySearchCriteria {
  SmartCollectionDefinition toSmartCollection({
    required String id,
    required String subjectId,
    required String name,
    required DateTime updatedAt,
    bool pinned = false,
  }) => SmartCollectionDefinition(
    id: id,
    subjectId: subjectId,
    name: name,
    query: query,
    tags: tags,
    kinds: kinds,
    partsOfSpeech: partsOfSpeech,
    learningStatuses: switch (learningState) {
      LibraryLearningStateFilter.learning => const {
        LearningStatus.learning,
        LearningStatus.review,
      },
      LibraryLearningStateFilter.mastered => const {LearningStatus.mastered},
      LibraryLearningStateFilter.suspended => const {LearningStatus.suspended},
      LibraryLearningStateFilter.unstudied => const {LearningStatus.newItem},
      _ => const {},
    },
    sourceIds: sources,
    dueOnly: learningState == LibraryLearningStateFilter.due,
    pinned: pinned,
    sort: switch (sortOrder) {
      LibrarySortOrder.alphabetical => SmartCollectionSort.alphabetical,
      LibrarySortOrder.recentlyStudied => SmartCollectionSort.recentlyStudied,
      LibrarySortOrder.lowestAccuracy => SmartCollectionSort.weakestFirst,
      LibrarySortOrder.nextReview => SmartCollectionSort.dueFirst,
      LibrarySortOrder.catalog => SmartCollectionSort.updatedNewest,
    },
    updatedAt: updatedAt,
  );

  static LibrarySearchCriteria fromSmartCollection(
    SmartCollectionDefinition definition,
  ) => LibrarySearchCriteria(
    query: definition.query,
    kinds: definition.kinds,
    partsOfSpeech: definition.partsOfSpeech,
    tags: definition.tags,
    sources: definition.sourceIds,
    learningState: definition.dueOnly
        ? LibraryLearningStateFilter.due
        : definition.learningStatuses.length == 1 &&
              definition.learningStatuses.contains(LearningStatus.newItem)
        ? LibraryLearningStateFilter.unstudied
        : definition.learningStatuses.length == 1 &&
              definition.learningStatuses.contains(LearningStatus.mastered)
        ? LibraryLearningStateFilter.mastered
        : definition.learningStatuses.length == 1 &&
              definition.learningStatuses.contains(LearningStatus.suspended)
        ? LibraryLearningStateFilter.suspended
        : definition.learningStatuses.isNotEmpty
        ? LibraryLearningStateFilter.learning
        : LibraryLearningStateFilter.all,
    sortOrder: switch (definition.sort) {
      SmartCollectionSort.alphabetical => LibrarySortOrder.alphabetical,
      SmartCollectionSort.recentlyStudied => LibrarySortOrder.recentlyStudied,
      SmartCollectionSort.weakestFirst => LibrarySortOrder.lowestAccuracy,
      SmartCollectionSort.dueFirst => LibrarySortOrder.nextReview,
      SmartCollectionSort.updatedNewest => LibrarySortOrder.catalog,
    },
  );
}

String foldLibrarySearchText(String value) {
  final decomposed = unicode.nfkd(unicode.nfkc(value)).toLowerCase();
  return decomposed
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool libraryItemMatches({
  required LearningItem item,
  required ProgressRecord? progress,
  required LibrarySearchCriteria criteria,
  required DateTime now,
  bool excluded = false,
}) {
  if (criteria.kinds.isNotEmpty && !criteria.kinds.contains(item.kind)) {
    return false;
  }
  if (criteria.partsOfSpeech.isNotEmpty &&
      !criteria.partsOfSpeech.contains(item.partOfSpeech)) {
    return false;
  }
  if (criteria.tags.isNotEmpty &&
      !criteria.tags.every((tag) => item.tags.contains(tag))) {
    return false;
  }
  if (criteria.sources.isNotEmpty &&
      !criteria.sources.contains(item.source.name)) {
    return false;
  }
  final due = progress?.nextReviewAt;
  final matchesLearningState = switch (criteria.learningState) {
    LibraryLearningStateFilter.all => true,
    LibraryLearningStateFilter.unstudied =>
      progress == null || progress.attempts == 0,
    LibraryLearningStateFilter.due =>
      due != null && !due.toUtc().isAfter(now.toUtc()),
    LibraryLearningStateFilter.learning =>
      progress != null &&
          (progress.status == LearningStatus.learning ||
              progress.status == LearningStatus.review),
    LibraryLearningStateFilter.mastered =>
      progress?.status == LearningStatus.mastered,
    LibraryLearningStateFilter.suspended =>
      excluded || progress?.status == LearningStatus.suspended,
  };
  if (!matchesLearningState) return false;

  final query = foldLibrarySearchText(criteria.query);
  if (query.isEmpty) return true;
  final haystack = foldLibrarySearchText(
    [
      item.text,
      ...item.translations,
      ...item.acceptedAnswers,
      ...item.readings.map((reading) => reading.value),
      if (item.example != null) item.example!,
      if (item.exampleTranslation != null) item.exampleTranslation!,
      ...item.tags,
      item.level,
      if (item.partOfSpeech != null) item.partOfSpeech!.koreanLabel,
      item.source.name,
      item.source.license,
      if (item.source.author != null) item.source.author!,
    ].join(' '),
  );
  return query.split(' ').every(haystack.contains);
}

List<LearningItem> filterAndSortLibraryItems({
  required Iterable<LearningItem> items,
  required Map<String, ProgressRecord> progressById,
  required LibrarySearchCriteria criteria,
  required DateTime now,
  Set<String> excludedItemIds = const {},
}) {
  final source = items.toList(growable: false);
  final originalIndex = {
    for (final (index, item) in source.indexed) item.id: index,
  };
  final result = source
      .where(
        (item) => libraryItemMatches(
          item: item,
          progress: progressById[item.id],
          criteria: criteria,
          now: now,
          excluded: excludedItemIds.contains(item.id),
        ),
      )
      .toList(growable: true);
  int stable(LearningItem left, LearningItem right, int order) {
    if (order != 0) return order;
    return (originalIndex[left.id] ?? 0).compareTo(
      originalIndex[right.id] ?? 0,
    );
  }

  int compareNullableDate(
    DateTime? left,
    DateTime? right, {
    required bool newestFirst,
  }) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return newestFirst ? right.compareTo(left) : left.compareTo(right);
  }

  switch (criteria.sortOrder) {
    case LibrarySortOrder.catalog:
      break;
    case LibrarySortOrder.alphabetical:
      result.sort(
        (left, right) => stable(
          left,
          right,
          foldLibrarySearchText(
            left.text,
          ).compareTo(foldLibrarySearchText(right.text)),
        ),
      );
    case LibrarySortOrder.recentlyStudied:
      result.sort(
        (left, right) => stable(
          left,
          right,
          compareNullableDate(
            progressById[left.id]?.lastStudiedAt,
            progressById[right.id]?.lastStudiedAt,
            newestFirst: true,
          ),
        ),
      );
    case LibrarySortOrder.lowestAccuracy:
      result.sort((left, right) {
        final leftProgress = progressById[left.id];
        final rightProgress = progressById[right.id];
        if (leftProgress == null && rightProgress == null) {
          return stable(left, right, 0);
        }
        if (leftProgress == null || leftProgress.attempts == 0) {
          return stable(left, right, 1);
        }
        if (rightProgress == null || rightProgress.attempts == 0) {
          return stable(left, right, -1);
        }
        return stable(
          left,
          right,
          leftProgress.accuracy.compareTo(rightProgress.accuracy),
        );
      });
    case LibrarySortOrder.nextReview:
      result.sort(
        (left, right) => stable(
          left,
          right,
          compareNullableDate(
            progressById[left.id]?.nextReviewAt,
            progressById[right.id]?.nextReviewAt,
            newestFirst: false,
          ),
        ),
      );
  }
  return List.unmodifiable(result);
}
