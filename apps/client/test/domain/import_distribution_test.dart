import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  test('provides one fallback distribution route per learning language', () {
    expect(fallbackImportDistributionRoutes, hasLength(6));
    expect(
      {
        for (final route in fallbackImportDistributionRoutes)
          route.key: (route.subjectId, route.languageCode),
      },
      {
        'lang:en': ('language:en', 'en'),
        'lang:ja': ('language:ja', 'ja'),
        'lang:de': ('language:de', 'de'),
        'lang:fr': ('language:fr', 'fr'),
        'lang:es': ('language:es', 'es'),
        'lang:zh-hans': ('language:zh-hans', 'zh-Hans'),
      },
    );
  });

  test('a saved rule overrides its built-in language fallback', () {
    final route = resolveImportDistributionRoute(
      ' LANG:EN ',
      savedRules: [
        ImportDistributionRule(
          key: 'lang:en',
          subjectId: 'language:ja',
          groupName: '직접 지정',
        ),
      ],
    );

    expect(route?.subjectId, 'language:ja');
    expect(route?.languageCode, LanguageTag.japanese.code);
    expect(route?.groupName, '직접 지정');
  });

  test('keeps safe custom keys while rejecting separators used by tags', () {
    expect(normalizeImportDistributionKey('  내 여행 @ 2026  '), '내-여행-@-2026');
    expect(
      () => normalizeImportDistributionKey('travel/core'),
      throwsFormatException,
    );
    expect(fallbackImportDistributionRouteFor('my-custom-key'), isNull);
  });
}
