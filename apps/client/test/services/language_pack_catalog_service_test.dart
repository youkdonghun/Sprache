import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/services/language_pack_catalog_service.dart';

void main() {
  final catalogUri = Uri.parse(
    'https://example.test/language-packs/catalog.json',
  );

  Map<String, Object?> pack({String term = 'hello'}) => {
    'schemaVersion': 1,
    'id': 'en-core-test',
    'title': '영어 핵심 테스트팩',
    'description': '다운로드 검증용 테스트 언어팩',
    'language': 'en',
    'version': '1.2.0',
    'revision': 2,
    'publishedAt': '2026-09-02T00:00:00Z',
    'license': 'CC0-1.0',
    'attribution': 'Sprache test fixture',
    'items': [
      {
        'id': 'en-core-test-word-1',
        'type': 'word',
        'term': term,
        'meaning': '안녕하세요',
        'part_of_speech': 'interjection',
      },
    ],
  };

  Map<String, Object?> catalog(List<int> packBytes) => {
    'schemaVersion': 1,
    'updatedAt': '2026-09-02T00:00:00Z',
    'packs': [
      {
        'id': 'en-core-test',
        'title': '영어 핵심 테스트팩',
        'description': '다운로드 검증용 테스트 언어팩',
        'language': 'en',
        'version': '1.2.0',
        'revision': 2,
        'publishedAt': '2026-09-02T00:00:00Z',
        'license': 'CC0-1.0',
        'attribution': 'Sprache test fixture',
        'path': 'packs/en-core-test.json',
        'itemCount': 1,
        'sizeBytes': packBytes.length,
        'sha256': sha256.convert(packBytes).toString(),
      },
    ],
  };

  test(
    'downloads, verifies and routes a GitHub language pack to import',
    () async {
      final packBytes = utf8.encode(jsonEncode(pack()));
      final catalogBytes = utf8.encode(jsonEncode(catalog(packBytes)));
      final client = MockClient((request) async {
        if (request.url == catalogUri) {
          return http.Response.bytes(catalogBytes, 200);
        }
        if (request.url ==
            Uri.parse(
              'https://example.test/language-packs/packs/en-core-test.json',
            )) {
          return http.Response.bytes(packBytes, 200);
        }
        return http.Response('not found', 404);
      });
      final service = LanguagePackCatalogService(
        catalogUri: catalogUri,
        client: client,
      );

      final loadedCatalog = await service.fetchCatalog();
      final descriptor = loadedCatalog.packs.single;
      expect(descriptor.language, LanguageTag.english);
      expect(descriptor.sourceId, 'language-pack:en-core-test');

      final downloaded = await service.downloadPack(descriptor);
      expect(downloaded.fileName, 'en-core-test-1.2.0.json');
      final wrapper = jsonDecode(utf8.decode(downloaded.bytes)) as Map;
      expect((wrapper['defaults'] as Map)['source_id'], descriptor.sourceId);
      expect((wrapper['items'] as List).single, isNot(contains('source_id')));
      final preview = const ContentImportParser().parseJson(
        utf8.decode(downloaded.bytes),
        defaultLanguage: LanguageTag.english,
      );
      expect(preview.issues, isEmpty);
      final item = preview.items.single;
      expect(item.text, 'hello');
      expect(item.effectiveSubjectId, 'language:en');
      expect(item.source.sourceId, 'language-pack:en-core-test');
      expect(item.source.sourceVersion, '1.2.0');
      expect(item.source.contentVersion, 2);
      expect(item.source.license, 'CC0-1.0');
    },
  );

  test('rejects a pack whose downloaded SHA-256 differs', () async {
    final originalBytes = utf8.encode(jsonEncode(pack()));
    final tamperedBytes = utf8.encode(jsonEncode(pack(term: 'jello')));
    final service = LanguagePackCatalogService(
      catalogUri: catalogUri,
      client: MockClient((request) async {
        if (request.url == catalogUri) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(catalog(originalBytes))),
            200,
          );
        }
        return http.Response.bytes(tamperedBytes, 200);
      }),
    );

    final descriptor = (await service.fetchCatalog()).packs.single;
    await expectLater(
      service.downloadPack(descriptor),
      throwsA(
        isA<LanguagePackCatalogException>().having(
          (error) => error.message,
          'message',
          contains('무결성'),
        ),
      ),
    );
  });

  test('rejects catalog paths that escape or change host', () async {
    final packBytes = utf8.encode(jsonEncode(pack()));
    final value = catalog(packBytes);
    final packs = value['packs']! as List<Object?>;
    (packs.single as Map<String, Object?>)['path'] = '../private.json';
    final service = LanguagePackCatalogService(
      catalogUri: catalogUri,
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(jsonEncode(value)), 200),
      ),
    );

    await expectLater(
      service.fetchCatalog(),
      throwsA(isA<LanguagePackCatalogException>()),
    );
  });

  test('repository catalog downloads and parses every real pack', () async {
    final repositoryRoot = Directory.current.parent.parent;
    final catalogUri = Uri.parse(
      'https://raw.githubusercontent.com/youkdonghun/Sprache/main/'
      'language-packs/catalog.json',
    );
    final service = LanguagePackCatalogService(
      catalogUri: catalogUri,
      client: MockClient((request) async {
        const marker = '/language-packs/';
        final markerIndex = request.url.path.indexOf(marker);
        if (markerIndex < 0) return http.Response('not found', 404);
        final relativePath = request.url.path.substring(
          markerIndex + marker.length,
        );
        final file = File(
          '${repositoryRoot.path}${Platform.pathSeparator}language-packs'
          '${Platform.pathSeparator}'
          '${relativePath.replaceAll('/', Platform.pathSeparator)}',
        );
        if (!file.existsSync()) return http.Response('not found', 404);
        return http.Response.bytes(await file.readAsBytes(), 200);
      }),
    );

    final catalog = await service.fetchCatalog();
    expect(catalog.packs, hasLength(8));
    expect(catalog.packs.map((pack) => pack.language).toSet(), {
      LanguageTag.english,
      LanguageTag.japanese,
      LanguageTag.german,
      LanguageTag.french,
      LanguageTag.spanish,
      LanguageTag.simplifiedChinese,
    });

    for (final descriptor in catalog.packs) {
      final downloaded = await service.downloadPack(descriptor);
      final preview = const ContentImportParser().parseJson(
        utf8.decode(downloaded.bytes),
        defaultLanguage: descriptor.language,
      );
      expect(preview.issues, isEmpty, reason: descriptor.id);
      expect(preview.items, hasLength(descriptor.itemCount));
      expect(
        preview.items.every(
          (item) =>
              item.learningLanguage == descriptor.language &&
              item.translations.isNotEmpty &&
              item.source.sourceId == descriptor.sourceId,
        ),
        isTrue,
        reason: descriptor.id,
      );
    }
  });
}
