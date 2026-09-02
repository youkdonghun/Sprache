import 'learning_item.dart';
import 'library_search.dart';
import 'local_search_query.dart';
import 'progress.dart';
import 'study_subject.dart';

sealed class GlobalSearchResult {
  const GlobalSearchResult({required this.subject, required this.score});

  final StudySubject subject;
  final int score;
}

class GlobalSubjectSearchResult extends GlobalSearchResult {
  const GlobalSubjectSearchResult({
    required super.subject,
    required super.score,
  });
}

class GlobalItemSearchResult extends GlobalSearchResult {
  const GlobalItemSearchResult({
    required super.subject,
    required this.item,
    required super.score,
  });

  final LearningItem item;
}

List<GlobalSearchResult> searchAcrossSubjects({
  required String query,
  required Iterable<StudySubject> subjects,
  required Iterable<LearningItem> items,
  Map<String, ProgressRecord> progressById = const {},
  Set<String> favoriteItemIds = const {},
  Set<String> excludedItemIds = const {},
  DateTime? now,
  int limit = 60,
}) {
  final parsed = LocalSearchQuery.parse(query);
  final tokens = parsed.textTokens;
  if (parsed.isEmpty) return const [];

  final subjectById = {for (final subject in subjects) subject.id: subject};
  final results = <GlobalSearchResult>[];
  for (final subject in subjectById.values) {
    if (parsed.hasOperators) continue;
    final text = foldLibrarySearchText(
      '${subject.name} ${subject.description} ${subject.symbol} '
      '${subject.contentLanguage.code} ${subject.contentLanguage.nativeName}',
    );
    if (!tokens.every(text.contains)) continue;
    results.add(
      GlobalSubjectSearchResult(
        subject: subject,
        score: _searchScore(text, tokens, subject.name),
      ),
    );
  }
  for (final item in items) {
    final subject = subjectById[item.effectiveSubjectId];
    if (subject == null) continue;
    if (!localSearchItemMatches(
      query: parsed,
      item: item,
      progress: progressById[item.id],
      favorite: favoriteItemIds.contains(item.id),
      excluded: excludedItemIds.contains(item.id),
      now: now,
    )) {
      continue;
    }
    final text = foldLibrarySearchText(
      [
        item.text,
        ...item.translations,
        ...item.acceptedAnswers,
        ...item.readings.map((reading) => reading.value),
        if (item.example != null) item.example!,
        if (item.exampleTranslation != null) item.exampleTranslation!,
        ...item.tags,
        item.level,
        item.source.name,
        subject.name,
      ].join(' '),
    );
    results.add(
      GlobalItemSearchResult(
        subject: subject,
        item: item,
        score:
            _searchScore(text, tokens, item.text) +
            (parsed.hasOperators ? 5 : 0),
      ),
    );
  }
  results.sort(_compareGlobalSearchResults);
  return List.unmodifiable(results.take(limit.clamp(1, 200)));
}

/// Searches a large catalog without monopolizing the UI isolate.
///
/// The matching rules intentionally mirror [searchAcrossSubjects], but the
/// item loop yields regularly so opening the palette and typing stay smooth on
/// web and lower-powered phones. A caller can invalidate obsolete searches
/// when a newer query arrives.
Future<List<GlobalSearchResult>> searchAcrossSubjectsCooperatively({
  required String query,
  required Iterable<StudySubject> subjects,
  required Iterable<LearningItem> items,
  Map<String, ProgressRecord> progressById = const {},
  Set<String> favoriteItemIds = const {},
  Set<String> excludedItemIds = const {},
  DateTime? now,
  int limit = 60,
  int yieldEvery = 160,
  bool Function()? isCancelled,
}) async {
  final parsed = LocalSearchQuery.parse(query);
  final tokens = parsed.textTokens;
  if (parsed.isEmpty) return const [];

  final subjectById = {for (final subject in subjects) subject.id: subject};
  final results = <GlobalSearchResult>[];
  for (final subject in subjectById.values) {
    if (parsed.hasOperators) continue;
    final text = foldLibrarySearchText(
      '${subject.name} ${subject.description} ${subject.symbol} '
      '${subject.contentLanguage.code} ${subject.contentLanguage.nativeName}',
    );
    if (!tokens.every(text.contains)) continue;
    results.add(
      GlobalSubjectSearchResult(
        subject: subject,
        score: _searchScore(text, tokens, subject.name),
      ),
    );
  }

  final effectiveYieldEvery = yieldEvery.clamp(40, 2000);
  var processed = 0;
  for (final item in items) {
    if (isCancelled?.call() ?? false) return const [];
    final subject = subjectById[item.effectiveSubjectId];
    if (subject != null &&
        localSearchItemMatches(
          query: parsed,
          item: item,
          progress: progressById[item.id],
          favorite: favoriteItemIds.contains(item.id),
          excluded: excludedItemIds.contains(item.id),
          now: now,
        )) {
      final text = foldLibrarySearchText(
        [
          item.text,
          ...item.translations,
          ...item.acceptedAnswers,
          ...item.readings.map((reading) => reading.value),
          if (item.example != null) item.example!,
          if (item.exampleTranslation != null) item.exampleTranslation!,
          ...item.tags,
          item.level,
          item.source.name,
          subject.name,
        ].join(' '),
      );
      results.add(
        GlobalItemSearchResult(
          subject: subject,
          item: item,
          score:
              _searchScore(text, tokens, item.text) +
              (parsed.hasOperators ? 5 : 0),
        ),
      );
    }
    processed += 1;
    if (processed % effectiveYieldEvery == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }
  if (isCancelled?.call() ?? false) return const [];
  results.sort(_compareGlobalSearchResults);
  return List.unmodifiable(results.take(limit.clamp(1, 200)));
}

int _compareGlobalSearchResults(
  GlobalSearchResult left,
  GlobalSearchResult right,
) {
  final score = right.score.compareTo(left.score);
  if (score != 0) return score;
  final subject = left.subject.name.compareTo(right.subject.name);
  if (subject != 0) return subject;
  final leftText = switch (left) {
    GlobalSubjectSearchResult() => left.subject.name,
    GlobalItemSearchResult(:final item) => item.text,
  };
  final rightText = switch (right) {
    GlobalSubjectSearchResult() => right.subject.name,
    GlobalItemSearchResult(:final item) => item.text,
  };
  return foldLibrarySearchText(
    leftText,
  ).compareTo(foldLibrarySearchText(rightText));
}

int _searchScore(String haystack, List<String> tokens, String primaryText) {
  final primary = foldLibrarySearchText(primaryText);
  var score = 0;
  for (final token in tokens) {
    if (primary == token) {
      score += 100;
    } else if (primary.startsWith(token)) {
      score += 60;
    } else if (primary.contains(token)) {
      score += 35;
    } else if (haystack.contains(token)) {
      score += 10;
    }
  }
  return score;
}
