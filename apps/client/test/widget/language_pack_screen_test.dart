import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/language_pack_screen.dart';
import 'package:sprache/src/services/language_pack_catalog_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('shows downloadable packs without overflowing on a phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);

    final packBytes = utf8.encode('{}');
    final catalogUri = Uri.parse(
      'https://example.test/language-packs/catalog.json',
    );
    final catalog = {
      'schemaVersion': 1,
      'updatedAt': '2026-09-02T00:00:00Z',
      'packs': [
        {
          'id': 'en-starter-test',
          'title': '영어 첫걸음 테스트팩',
          'description': '앱을 다시 설치하지 않고 추가하는 공개 학습 자료',
          'language': 'en',
          'version': '1.0.0',
          'revision': 1,
          'license': 'CC0-1.0',
          'attribution': 'Sprache test fixture',
          'path': 'packs/en-starter-test.json',
          'itemCount': 120,
          'sizeBytes': packBytes.length,
          'sha256': sha256.convert(packBytes).toString(),
        },
      ],
    };
    final service = LanguagePackCatalogService(
      catalogUri: catalogUri,
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(jsonEncode(catalog)), 200),
      ),
    );
    addTearDown(service.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(
            MemoryStudyStore(
              preferences: const StudyPreferences(onboardingCompleted: true),
            ),
          ),
        ],
        child: MaterialApp(home: LanguagePackScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('영어 첫걸음 테스트팩'), findsOneWidget);
    expect(find.text('검토하고 설치'), findsOneWidget);
    expect(find.textContaining('앱 업데이트 없이'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains an empty GitHub catalog clearly', (tester) async {
    final service = LanguagePackCatalogService(
      catalogUri: Uri.parse('https://example.test/language-packs/catalog.json'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'schemaVersion': 1,
            'updatedAt': null,
            'packs': <Object?>[],
          }),
          200,
        ),
      ),
    );
    addTearDown(service.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(
            MemoryStudyStore(
              preferences: const StudyPreferences(onboardingCompleted: true),
            ),
          ),
        ],
        child: MaterialApp(home: LanguagePackScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('공개된 언어팩이 아직 없어요.'), findsOneWidget);
    expect(find.textContaining('앱 업데이트 없이'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
