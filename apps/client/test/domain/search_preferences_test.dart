import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/search_preferences.dart';

void main() {
  test('recent searches are deduplicated, newest first, and bounded to 20', () {
    var preferences = const SearchLocalPreferences();
    for (var index = 0; index < 25; index++) {
      preferences = preferences.rememberGlobal(' query $index ');
      preferences = preferences.rememberSubject('language:en', 'query $index');
    }
    preferences = preferences.rememberGlobal('QUERY 24');

    expect(preferences.globalRecent, hasLength(20));
    expect(preferences.globalRecent.first, 'QUERY 24');
    expect(preferences.recentForSubject('language:en'), hasLength(20));
    expect(
      preferences.globalRecent.where((value) => value == 'query 24'),
      isEmpty,
    );
  });

  test('individual global and subject queries can be removed', () {
    final preferences = const SearchLocalPreferences()
        .rememberGlobal('bonjour')
        .rememberGlobal('hello')
        .rememberSubject('language:fr', 'bonjour')
        .removeGlobal('bonjour')
        .removeSubject('language:fr', 'bonjour');

    expect(preferences.globalRecent, ['hello']);
    expect(preferences.recentForSubject('language:fr'), isEmpty);
  });

  test('malformed JSON is decoded defensively and remains bounded', () {
    final preferences = SearchLocalPreferences.fromJson({
      'globalRecent': [...List.generate(30, (index) => 'q$index'), 3, null],
      'recentBySubject': {
        'language:en': List.generate(30, (index) => 'english $index'),
        'bad': 'not-a-list',
        4: ['ignored'],
      },
      'globalResultLayout': 'not-supported',
    });

    expect(preferences.globalRecent, hasLength(20));
    expect(preferences.recentForSubject('language:en'), hasLength(20));
    expect(preferences.recentForSubject('bad'), isEmpty);
    expect(preferences.globalResultLayout, GlobalSearchResultLayout.score);
    expect(preferences.libraryViewMode, LibraryViewMode.spacious);

    final restored = SearchLocalPreferences.fromJson(
      preferences.copyWith(libraryViewMode: LibraryViewMode.grid).toJson(),
    );
    expect(restored.globalRecent, preferences.globalRecent);
    expect(restored.recentBySubject, preferences.recentBySubject);
    expect(restored.libraryViewMode, LibraryViewMode.grid);
  });

  test('legacy JSON without a library view remains spacious', () {
    final restored = SearchLocalPreferences.fromJson({
      'version': 1,
      'globalRecent': ['hello'],
    });

    expect(restored.libraryViewMode, LibraryViewMode.spacious);
    expect(restored.globalRecent, ['hello']);
  });
}
