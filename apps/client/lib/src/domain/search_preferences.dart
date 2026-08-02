enum GlobalSearchResultLayout { score, subject }

enum LibraryViewMode { spacious, compact, grid }

/// Device-local search history and presentation preferences.
///
/// Search history is intentionally kept out of the Drive snapshot: it can
/// contain unfinished or private queries and is useful only on the device on
/// which it was entered. Every collection is bounded while decoding as well as
/// while updating, so a damaged settings row cannot grow the in-memory model.
class SearchLocalPreferences {
  const SearchLocalPreferences({
    this.globalRecent = const [],
    this.recentBySubject = const {},
    this.globalResultLayout = GlobalSearchResultLayout.score,
    this.libraryViewMode = LibraryViewMode.spacious,
  });

  factory SearchLocalPreferences.fromJson(Map<String, Object?> json) {
    final recentBySubject = <String, List<String>>{};
    if (json['recentBySubject'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(100)) {
        final subjectId = entry.key;
        final values = entry.value;
        if (subjectId is! String ||
            subjectId.trim().isEmpty ||
            subjectId.runes.length > 100 ||
            values is! List<Object?>) {
          continue;
        }
        final safe = _safeRecentSearches(values);
        if (safe.isNotEmpty) recentBySubject[subjectId] = safe;
      }
    }
    final layoutName = json['globalResultLayout'];
    final layout = layoutName is String
        ? GlobalSearchResultLayout.values.firstWhere(
            (value) => value.name == layoutName,
            orElse: () => GlobalSearchResultLayout.score,
          )
        : GlobalSearchResultLayout.score;
    final viewModeName = json['libraryViewMode'];
    final viewMode = viewModeName is String
        ? LibraryViewMode.values.firstWhere(
            (value) => value.name == viewModeName,
            orElse: () => LibraryViewMode.spacious,
          )
        : LibraryViewMode.spacious;
    return SearchLocalPreferences(
      globalRecent: _safeRecentSearches(
        json['globalRecent'] is List<Object?>
            ? json['globalRecent']! as List<Object?>
            : const [],
      ),
      recentBySubject: Map<String, List<String>>.unmodifiable({
        for (final entry in recentBySubject.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      }),
      globalResultLayout: layout,
      libraryViewMode: viewMode,
    );
  }

  final List<String> globalRecent;
  final Map<String, List<String>> recentBySubject;
  final GlobalSearchResultLayout globalResultLayout;
  final LibraryViewMode libraryViewMode;

  List<String> recentForSubject(String subjectId) =>
      recentBySubject[subjectId] ?? const [];

  SearchLocalPreferences rememberGlobal(String query) =>
      copyWith(globalRecent: _remember(globalRecent, query));

  SearchLocalPreferences rememberSubject(String subjectId, String query) {
    final normalizedSubject = subjectId.trim();
    if (normalizedSubject.isEmpty || normalizedSubject.runes.length > 100) {
      return this;
    }
    final remembered = _remember(recentForSubject(normalizedSubject), query);
    if (remembered.isEmpty) return this;
    final next = <String, List<String>>{
      ...recentBySubject,
      normalizedSubject: remembered,
    };
    while (next.length > 100) {
      next.remove(next.keys.first);
    }
    return copyWith(recentBySubject: next);
  }

  SearchLocalPreferences removeGlobal(String query) =>
      copyWith(globalRecent: _remove(globalRecent, query));

  SearchLocalPreferences removeSubject(String subjectId, String query) {
    final next = <String, List<String>>{...recentBySubject};
    final remaining = _remove(recentForSubject(subjectId), query);
    if (remaining.isEmpty) {
      next.remove(subjectId);
    } else {
      next[subjectId] = remaining;
    }
    return copyWith(recentBySubject: next);
  }

  SearchLocalPreferences copyWith({
    List<String>? globalRecent,
    Map<String, List<String>>? recentBySubject,
    GlobalSearchResultLayout? globalResultLayout,
    LibraryViewMode? libraryViewMode,
  }) => SearchLocalPreferences(
    globalRecent: List<String>.unmodifiable(
      _safeRecentSearches(globalRecent ?? this.globalRecent),
    ),
    recentBySubject: Map<String, List<String>>.unmodifiable({
      for (final entry
          in (recentBySubject ?? this.recentBySubject).entries.take(100))
        if (entry.key.trim().isNotEmpty && entry.key.runes.length <= 100)
          entry.key: List<String>.unmodifiable(
            _safeRecentSearches(entry.value),
          ),
    }),
    globalResultLayout: globalResultLayout ?? this.globalResultLayout,
    libraryViewMode: libraryViewMode ?? this.libraryViewMode,
  );

  Map<String, Object?> toJson() => {
    'version': 2,
    'globalRecent': globalRecent,
    'recentBySubject': recentBySubject,
    'globalResultLayout': globalResultLayout.name,
    'libraryViewMode': libraryViewMode.name,
  };
}

List<String> _remember(Iterable<Object?> current, String query) {
  final normalized = _normalizeStoredQuery(query);
  if (normalized.isEmpty) return _safeRecentSearches(current);
  return _safeRecentSearches([
    normalized,
    ...current.where(
      (value) =>
          value is! String ||
          _normalizeStoredQuery(value).toLowerCase() !=
              normalized.toLowerCase(),
    ),
  ]);
}

List<String> _remove(Iterable<Object?> current, String query) {
  final target = _normalizeStoredQuery(query).toLowerCase();
  return _safeRecentSearches(
    current.where(
      (value) =>
          value is! String ||
          _normalizeStoredQuery(value).toLowerCase() != target,
    ),
  );
}

List<String> _safeRecentSearches(Iterable<Object?> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in values) {
    if (raw is! String) continue;
    final query = _normalizeStoredQuery(raw);
    if (query.isEmpty || !seen.add(query.toLowerCase())) continue;
    result.add(query);
    if (result.length == 20) break;
  }
  return List<String>.unmodifiable(result);
}

String _normalizeStoredQuery(String value) => String.fromCharCodes(
  value.trim().replaceAll(RegExp(r'\s+'), ' ').runes.take(160),
);
