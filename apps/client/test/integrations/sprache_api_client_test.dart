import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/integrations/google/sprache_api_client.dart';

void main() {
  test('reads the existing Railway Drive root binding', () async {
    final client = SpracheApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/me/drive-root');
        expect(request.headers['authorization'], 'Bearer id-token');
        return http.Response(
          jsonEncode({
            'binding': {
              'folderId': 'existing-root-id',
              'folderName': 'WordStudyData',
              'schemaVersion': 1,
              'createdAt': '2026-07-29T00:00:00.000Z',
              'updatedAt': '2026-07-29T00:00:00.000Z',
            },
          }),
          200,
        );
      }),
    );

    final binding = await client.getDriveRoot(idToken: 'id-token');

    expect(binding, isNotNull);
    expect(binding!.folderId, 'existing-root-id');
    expect(binding.folderName, 'WordStudyData');
    expect(binding.schemaVersion, 1);
  });

  test('returns null when Railway has no Drive root binding', () async {
    final client = SpracheApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: MockClient(
        (_) async => http.Response(jsonEncode({'binding': null}), 200),
      ),
    );

    expect(await client.getDriveRoot(idToken: 'id-token'), isNull);
  });

  test('deletes only the authenticated Railway Drive root binding', () async {
    final client = SpracheApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/v1/me/drive-root');
        expect(request.headers['authorization'], 'Bearer id-token');
        return http.Response('', 204);
      }),
    );

    await client.deleteDriveRoot(idToken: 'id-token');
  });
}
