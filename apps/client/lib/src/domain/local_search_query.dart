import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'learning_group.dart';
import 'learning_item.dart';
import 'progress.dart';

enum LocalSearchItemType { word, sentence }

enum LocalSearchLearningState {
  favorite,
  due,
  learning,
  mastered,
  suspended,
  unstudied,
  weak,
  wrong,
}

class LocalSearchQuery {
  const LocalSearchQuery({
    required this.raw,
    this.textTokens = const [],
    this.tags = const [],
    this.types = const {},
    this.states = const {},
    this.groups = const [],
  });

  factory LocalSearchQuery.parse(String raw) {
    final text = <String>[];
    final tags = <String>[];
    final types = <LocalSearchItemType>{};
    final states = <LocalSearchLearningState>{};
    final groups = <String>[];
    for (final token in _tokenize(raw)) {
      final separator = token.indexOf(':');
      if (separator <= 0 || separator == token.length - 1) {
        text.addAll(_foldTokens(token));
        continue;
      }
      final key = token.substring(0, separator).toLowerCase();
      final rawValue = token.substring(separator + 1).trim();
      final value = foldLocalSearchText(rawValue);
      var recognized = value.isNotEmpty;
      switch (key) {
        case 'tag':
          if (recognized) tags.add(value);
        case 'group':
          if (recognized) groups.add(value);
        case 'type':
          final parsed = _parseType(value);
          recognized = parsed != null;
          if (parsed != null) types.add(parsed);
        case 'state':
          final parsed = _parseState(value);
          recognized = parsed != null;
          if (parsed != null) states.add(parsed);
        default:
          recognized = false;
      }
      if (!recognized) text.addAll(_foldTokens(token));
    }
    return LocalSearchQuery(
      raw: raw,
      textTokens: List.unmodifiable(text),
      tags: List.unmodifiable(tags),
      types: Set.unmodifiable(types),
      states: Set.unmodifiable(states),
      groups: List.unmodifiable(groups),
    );
  }

  final String raw;
  final List<String> textTokens;
  final List<String> tags;
  final Set<LocalSearchItemType> types;
  final Set<LocalSearchLearningState> states;
  final List<String> groups;

  bool get isEmpty =>
      textTokens.isEmpty &&
      tags.isEmpty &&
      types.isEmpty &&
      states.isEmpty &&
      groups.isEmpty;

  bool get hasOperators =>
      tags.isNotEmpty ||
      types.isNotEmpty ||
      states.isNotEmpty ||
      groups.isNotEmpty;

  String get plainText => textTokens.join(' ');
}

String foldLocalSearchText(String value) {
  final decomposed = unicode.nfkd(unicode.nfkc(value)).toLowerCase();
  return decomposed
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool localSearchItemMatches({
  required LocalSearchQuery query,
  required LearningItem item,
  ProgressRecord? progress,
  bool favorite = false,
  bool excluded = false,
  DateTime? now,
}) {
  if (query.types.isNotEmpty) {
    final type = item.kind == LearningItemKind.word
        ? LocalSearchItemType.word
        : LocalSearchItemType.sentence;
    if (!query.types.contains(type)) return false;
  }
  final itemTags = item.tags
      .where((tag) => !tag.startsWith(learningGroupTagPrefix))
      .map(foldLocalSearchText)
      .toList(growable: false);
  if (!query.tags.every(
    (target) => itemTags.any((tag) => tag.contains(target)),
  )) {
    return false;
  }
  final groups = learningGroupsOf(item).map(foldLocalSearchText);
  if (!query.groups.every(
    (target) => groups.any((group) => group.contains(target)),
  )) {
    return false;
  }
  final effectiveNow = (now ?? DateTime.now()).toUtc();
  for (final state in query.states) {
    final matches = switch (state) {
      LocalSearchLearningState.favorite => favorite,
      LocalSearchLearningState.due =>
        progress?.nextReviewAt != null &&
            !progress!.nextReviewAt!.toUtc().isAfter(effectiveNow),
      LocalSearchLearningState.learning =>
        progress?.status == LearningStatus.learning ||
            progress?.status == LearningStatus.review,
      LocalSearchLearningState.mastered =>
        progress?.status == LearningStatus.mastered,
      LocalSearchLearningState.suspended =>
        excluded || progress?.status == LearningStatus.suspended,
      LocalSearchLearningState.unstudied =>
        progress == null || progress.attempts == 0,
      LocalSearchLearningState.weak =>
        progress != null && progress.attempts > 0 && progress.accuracy < 0.7,
      LocalSearchLearningState.wrong =>
        progress?.lastResult == ReviewRating.again,
    };
    if (!matches) return false;
  }
  if (query.textTokens.isEmpty) return true;
  final haystack = foldLocalSearchText(
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
  return query.textTokens.every(haystack.contains);
}

class SearchHighlightRange {
  const SearchHighlightRange(this.start, this.end);

  final int start;
  final int end;
}

List<SearchHighlightRange> searchHighlightRanges(String text, String query) {
  final parsed = LocalSearchQuery.parse(query);
  if (text.isEmpty || parsed.textTokens.isEmpty) return const [];
  final mapped = _MappedSearchText.from(text);
  final ranges = <SearchHighlightRange>[];
  for (final token in parsed.textTokens) {
    var cursor = 0;
    while (cursor < mapped.value.length) {
      final found = mapped.value.indexOf(token, cursor);
      if (found < 0) break;
      final last = found + token.length - 1;
      if (found < mapped.starts.length && last < mapped.ends.length) {
        ranges.add(
          SearchHighlightRange(mapped.starts[found], mapped.ends[last]),
        );
      }
      cursor = found + token.length;
    }
  }
  if (ranges.isEmpty) return const [];
  ranges.sort((left, right) => left.start.compareTo(right.start));
  final merged = <SearchHighlightRange>[];
  for (final range in ranges) {
    if (merged.isEmpty || range.start > merged.last.end) {
      merged.add(range);
    } else if (range.end > merged.last.end) {
      merged[merged.length - 1] = SearchHighlightRange(
        merged.last.start,
        range.end,
      );
    }
  }
  return List.unmodifiable(merged);
}

List<String> suggestSimilarSearches({
  required String query,
  required Iterable<String> candidates,
  int limit = 5,
}) {
  final parsed = LocalSearchQuery.parse(query);
  final needle = parsed.plainText;
  if (needle.isEmpty) return const [];
  final scored = <(String, int)>[];
  final seen = <String>{};
  for (final raw in candidates.take(2000)) {
    final candidate = raw.trim();
    final folded = foldLocalSearchText(candidate);
    if (folded.isEmpty || folded == needle || !seen.add(folded)) continue;
    final distance = _levenshtein(needle, folded);
    final threshold = (needle.length * 0.45).ceil().clamp(1, 5);
    if (distance <= threshold ||
        folded.startsWith(needle) ||
        needle.startsWith(folded)) {
      scored.add((candidate, distance));
    }
  }
  scored.sort((left, right) {
    final score = left.$2.compareTo(right.$2);
    if (score != 0) return score;
    return left.$1.length.compareTo(right.$1.length);
  });
  return List.unmodifiable(
    scored.take(limit.clamp(1, 10)).map((entry) => entry.$1),
  );
}

List<String> _tokenize(String value) {
  final tokens = <String>[];
  var current = StringBuffer();
  String? quote;
  void finish() {
    final token = current.toString().trim();
    if (token.isNotEmpty) tokens.add(token);
    current = StringBuffer();
  }

  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (quote != null) {
      if (character == quote) {
        quote = null;
      } else {
        current.write(character);
      }
      continue;
    }
    if (character == '"' || character == "'") {
      quote = character;
    } else if (RegExp(r'\s').hasMatch(character)) {
      finish();
    } else {
      current.write(character);
    }
  }
  finish();
  return tokens;
}

List<String> _foldTokens(String value) => foldLocalSearchText(
  value,
).split(' ').where((token) => token.isNotEmpty).toList(growable: false);

LocalSearchItemType? _parseType(String value) => switch (value) {
  'word' || 'words' || '단어' => LocalSearchItemType.word,
  'sentence' || 'sentences' || '문장' => LocalSearchItemType.sentence,
  _ => null,
};

LocalSearchLearningState? _parseState(String value) => switch (value) {
  'favorite' ||
  'favorites' ||
  'saved' ||
  '저장' ||
  '즐겨찾기' => LocalSearchLearningState.favorite,
  'due' || '복습' || '예정' => LocalSearchLearningState.due,
  'learning' || '학습' => LocalSearchLearningState.learning,
  'mastered' || '완료' || '익힘' => LocalSearchLearningState.mastered,
  'suspended' ||
  'excluded' ||
  '보류' ||
  '제외' => LocalSearchLearningState.suspended,
  'new' || 'unstudied' || '미학습' || '새항목' => LocalSearchLearningState.unstudied,
  'weak' || '취약' => LocalSearchLearningState.weak,
  'wrong' || '오답' => LocalSearchLearningState.wrong,
  _ => null,
};

int _levenshtein(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 0; i < left.length; i++) {
    final current = <int>[i + 1];
    for (var j = 0; j < right.length; j++) {
      current.add(
        [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + (left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1),
        ].reduce((a, b) => a < b ? a : b),
      );
    }
    previous = current;
  }
  return previous.last;
}

class _MappedSearchText {
  const _MappedSearchText(this.value, this.starts, this.ends);

  factory _MappedSearchText.from(String original) {
    final value = StringBuffer();
    final starts = <int>[];
    final ends = <int>[];
    var offset = 0;
    var pendingSpace = false;
    for (final rune in original.runes) {
      final source = String.fromCharCode(rune);
      final folded = unicode
          .nfkd(unicode.nfkc(source))
          .toLowerCase()
          .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
      final runeLength = source.length;
      for (final foldedRune in folded.runes) {
        final char = String.fromCharCode(foldedRune);
        final searchable = RegExp(
          r'[\p{L}\p{N}]',
          unicode: true,
        ).hasMatch(char);
        if (!searchable) {
          pendingSpace = value.isNotEmpty;
          continue;
        }
        if (pendingSpace && !value.toString().endsWith(' ')) {
          value.write(' ');
          starts.add(offset);
          ends.add(offset + runeLength);
        }
        pendingSpace = false;
        value.write(char);
        for (var i = 0; i < char.length; i++) {
          starts.add(offset);
          ends.add(offset + runeLength);
        }
      }
      offset += runeLength;
    }
    return _MappedSearchText(value.toString(), starts, ends);
  }

  final String value;
  final List<int> starts;
  final List<int> ends;
}
