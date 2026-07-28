import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/integrations/google/google_drive_client.dart';

void main() {
  const appRootId = 'app-root';
  final snapshot = <String, Object?>{'schemaVersion': 1, 'totalXp': 120};
  final snapshotBytes = utf8.encode(jsonEncode(snapshot));
  final snapshotSha = sha256.convert(snapshotBytes).toString();

  Map<String, Object?> manifest({String revision = '7', String? sha}) => {
    'schemaVersion': 1,
    'datasetVersion': 1,
    'appRootFolderId': appRootId,
    'files': {
      'state/snapshot.json': {
        'fileId': 'snapshot-file',
        'revision': revision,
        'sha256': sha ?? snapshotSha,
        'updatedAt': '2026-07-28T10:00:00.000Z',
      },
    },
    'updatedAt': '2026-07-28T10:00:00.000Z',
  };

  test(
    'reads the manifest file id and verifies revision and SHA-256',
    () async {
      final requestedPaths = <String>[];
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          requestedPaths.add('${request.method} ${request.url.path}');
          if (request.url.path == '/drive/v3/files') {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'manifest-file'},
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/drive/v3/files/manifest-file') {
            return http.Response(jsonEncode(manifest()), 200);
          }
          if (request.url.path == '/drive/v3/files/snapshot-file' &&
              request.url.queryParameters['alt'] == 'media') {
            return http.Response.bytes(snapshotBytes, 200);
          }
          if (request.url.path == '/drive/v3/files/snapshot-file') {
            return http.Response(
              jsonEncode({
                'id': 'snapshot-file',
                'version': '7',
                'modifiedTime': '2026-07-28T10:00:00.000Z',
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      expect(await client.readStateSnapshot(appRootId), snapshot);
      expect(
        requestedPaths,
        containsAllInOrder([
          'GET /drive/v3/files',
          'GET /drive/v3/files/manifest-file',
          'GET /drive/v3/files/snapshot-file',
          'GET /drive/v3/files/snapshot-file',
        ]),
      );
    },
  );

  test(
    'rejects snapshot bytes whose SHA does not match the manifest',
    () async {
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: _readClient(
          manifest: manifest(sha: '0' * 64),
          snapshotBytes: snapshotBytes,
        ),
      );

      await expectLater(
        client.readStateSnapshot(appRootId),
        throwsA(
          isA<DriveDataIntegrityException>().having(
            (error) => error.code,
            'code',
            'drive_manifest_sha_mismatch',
          ),
        ),
      );
    },
  );

  test('rejects a newer Drive revision before overwriting it', () async {
    var uploadCount = 0;
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          uploadCount += 1;
          return http.Response('', 200);
        }
        if (request.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'manifest-file'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/drive/v3/files/manifest-file') {
          return http.Response(jsonEncode(manifest()), 200);
        }
        if (request.url.path == '/drive/v3/files/snapshot-file') {
          return http.Response(
            jsonEncode({'id': 'snapshot-file', 'version': '8'}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await expectLater(
      client.writeStateSnapshot(appRootId: appRootId, snapshot: snapshot),
      throwsA(
        isA<DriveDataIntegrityException>().having(
          (error) => error.code,
          'code',
          'drive_upload_conflict',
        ),
      ),
    );
    expect(uploadCount, 0);
  });

  test('rejects a manifest changed after pull and before push', () async {
    var manifestReads = 0;
    var uploadCount = 0;
    final newerSnapshot = <String, Object?>{'schemaVersion': 1, 'totalXp': 500};
    final newerBytes = utf8.encode(jsonEncode(newerSnapshot));
    final newerSha = sha256.convert(newerBytes).toString();
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          uploadCount += 1;
          return http.Response('', 200);
        }
        if (request.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'manifest-file'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/drive/v3/files/manifest-file') {
          manifestReads += 1;
          return http.Response(
            jsonEncode(
              manifestReads == 1
                  ? manifest()
                  : manifest(revision: '8', sha: newerSha),
            ),
            200,
          );
        }
        if (request.url.path == '/drive/v3/files/snapshot-file' &&
            request.url.queryParameters['alt'] == 'media') {
          return http.Response.bytes(snapshotBytes, 200);
        }
        if (request.url.path == '/drive/v3/files/snapshot-file') {
          return http.Response(
            jsonEncode({'id': 'snapshot-file', 'version': '7'}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    expect(await client.readStateSnapshot(appRootId), snapshot);
    await expectLater(
      client.writeStateSnapshot(appRootId: appRootId, snapshot: snapshot),
      throwsA(
        isA<DriveDataIntegrityException>().having(
          (error) => error.code,
          'code',
          'drive_upload_conflict',
        ),
      ),
    );
    expect(uploadCount, 0);
  });

  test('does not disguise a Drive HTTP failure as corrupt JSON', () async {
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'manifest-file'},
              ],
            }),
            200,
          );
        }
        return http.Response('temporarily unavailable', 503);
      }),
    );

    await expectLater(
      client.readStateSnapshot(appRootId),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });
}

MockClient _readClient({
  required Map<String, Object?> manifest,
  required List<int> snapshotBytes,
}) {
  return MockClient((request) async {
    if (request.url.path == '/drive/v3/files') {
      return http.Response(
        jsonEncode({
          'files': [
            {'id': 'manifest-file'},
          ],
        }),
        200,
      );
    }
    if (request.url.path == '/drive/v3/files/manifest-file') {
      return http.Response(jsonEncode(manifest), 200);
    }
    if (request.url.path == '/drive/v3/files/snapshot-file' &&
        request.url.queryParameters['alt'] == 'media') {
      return http.Response.bytes(snapshotBytes, 200);
    }
    if (request.url.path == '/drive/v3/files/snapshot-file') {
      return http.Response(
        jsonEncode({'id': 'snapshot-file', 'version': '7'}),
        200,
      );
    }
    return http.Response('not found', 404);
  });
}
