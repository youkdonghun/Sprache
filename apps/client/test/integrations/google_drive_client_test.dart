import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/integrations/google/google_drive_client.dart';
import 'package:sprache/src/sync/sync_dataset.dart';

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
    'accepts metadata-only Drive revision drift when SHA-256 is unchanged',
    () async {
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
          if (request.url.path == '/drive/v3/files/manifest-file') {
            return http.Response(jsonEncode(manifest()), 200);
          }
          if (request.url.path == '/drive/v3/files/snapshot-file' &&
              request.url.queryParameters['alt'] == 'media') {
            return http.Response.bytes(snapshotBytes, 200);
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

      expect(await client.readStateSnapshot(appRootId), snapshot);
    },
  );

  test(
    'rejects and quarantines snapshot bytes whose SHA does not match',
    () async {
      var copyCount = 0;
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.url.path == '/drive/v3/files') {
            final query = request.url.queryParameters['q'] ?? '';
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': query.contains("name = 'quarantine'")
                        ? 'quarantine-folder'
                        : 'manifest-file',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/drive/v3/files/manifest-file') {
            return http.Response(jsonEncode(manifest(sha: '0' * 64)), 200);
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
          if (request.url.path == '/drive/v3/files/snapshot-file/copy') {
            copyCount += 1;
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['parents'], ['quarantine-folder']);
            return http.Response(
              jsonEncode({'id': 'quarantine-copy', 'name': body['name']}),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      try {
        await client.readStateSnapshot(appRootId);
        fail('Expected a DriveDataIntegrityException.');
      } on DriveDataIntegrityException catch (error) {
        expect(error.code, 'drive_manifest_sha_mismatch');
        expect(error.quarantine?.fileId, 'quarantine-copy');
        expect(error.quarantine?.sourceFileId, 'snapshot-file');
        expect(error.quarantine?.reasonCode, error.code);
        expect(
          error.quarantine?.preview,
          contains('${snapshotBytes.length} bytes'),
        );
        expect(error.quarantine?.preview, isNot(contains('totalXp')));
      }
      expect(copyCount, 1);
    },
  );

  test('rejects a newer Drive revision before overwriting it', () async {
    var uploadCount = 0;
    final changedBytes = utf8.encode(
      jsonEncode(<String, Object?>{'schemaVersion': 1, 'totalXp': 999}),
    );
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
          if (request.url.queryParameters['alt'] == 'media') {
            return http.Response.bytes(changedBytes, 200);
          }
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

  test(
    'classifies a temporary Drive HTTP failure without calling it corrupt',
    () async {
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
          isA<DriveRequestException>()
              .having(
                (error) => error.failure,
                'failure',
                DriveRequestFailure.serviceUnavailable,
              )
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    },
  );

  test('distinguishes rate limits from Drive storage quota failures', () async {
    Future<DriveRequestException> failureFor(
      String reason, {
      String? retryAfter,
    }) async {
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {
                'errors': [
                  {'reason': reason},
                ],
              },
            }),
            403,
            headers: retryAfter == null
                ? const {}
                : {'retry-after': retryAfter},
          );
        }),
      );
      try {
        await client.readStateSnapshot(appRootId);
        fail('Expected a DriveRequestException.');
      } on DriveRequestException catch (error) {
        return error;
      }
    }

    final rateLimited = await failureFor(
      'userRateLimitExceeded',
      retryAfter: '45',
    );
    expect(rateLimited.failure, DriveRequestFailure.rateLimited);
    expect(rateLimited.retryable, isTrue);
    expect(rateLimited.retryAfter, const Duration(seconds: 45));

    final dailyLimit = await failureFor('dailyLimitExceeded');
    expect(dailyLimit.failure, DriveRequestFailure.rateLimited);
    expect(dailyLimit.retryable, isTrue);

    final quotaExceeded = await failureFor('storageQuotaExceeded');
    expect(quotaExceeded.failure, DriveRequestFailure.quotaExceeded);
    expect(quotaExceeded.retryable, isFalse);
    expect(quotaExceeded.reconnectRequired, isFalse);
  });

  test('maps a transport abort to a retryable Drive failure', () async {
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        throw http.ClientException(
          'Software caused connection abort',
          request.url,
        );
      }),
    );

    try {
      await client.readStateSnapshot(appRootId);
      fail('Expected a DriveRequestException.');
    } on DriveRequestException catch (error) {
      expect(error.failure, DriveRequestFailure.serviceUnavailable);
      expect(error.statusCode, 0);
      expect(error.retryable, isTrue);
      expect(error.reconnectRequired, isFalse);
      expect(error.operation, 'read Drive metadata');
      expect(error.toString(), isNot(contains('googleapis.com')));
      expect(error.toString(), isNot(contains('ClientException')));
    }
  });

  test(
    'migrates a legacy snapshot to one canonical file and keeps its file id',
    () async {
      final legacySnapshot = <String, Object?>{
        'schemaVersion': 1,
        'updatedAt': '2026-07-29T00:00:00.000Z',
        'profile': {'totalXp': 120},
        'settings': {'dailyGoal': 100},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: legacySnapshot,
      );
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );

      expect(await client.readStateSnapshot(appRootId), legacySnapshot);
      backend.uploadedNames.clear();
      await client.writeStateSnapshot(
        appRootId: appRootId,
        snapshot: legacySnapshot,
      );

      final migratedManifest = backend.manifest;
      expect(migratedManifest['layout'], SyncDatasetCodec.canonicalLayout);
      final migratedFiles = migratedManifest['files']! as Map<String, Object?>;
      expect(migratedFiles.keys, [SyncDatasetCodec.canonicalPath]);
      expect(
        (migratedFiles[SyncDatasetCodec.canonicalPath]! as Map)['fileId'],
        'snapshot-file',
      );
      expect(backend.uploadedNames, ['snapshot.json', 'manifest.json']);

      final reader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await reader.readStateSnapshot(appRootId), legacySnapshot);

      backend.uploadedNames.clear();
      final profileOnlyChange = <String, Object?>{
        ...legacySnapshot,
        'profile': {'totalXp': 150},
      };
      await reader.writeStateSnapshot(
        appRootId: appRootId,
        snapshot: profileOnlyChange,
      );

      expect(backend.uploadedNames, hasLength(2));
      expect(backend.uploadedNames.first, 'snapshot.json');
      expect(backend.uploadedNames.last, 'manifest.json');
      final finalFiles = backend.manifest['files']! as Map<String, Object?>;
      expect(
        (finalFiles[SyncDatasetCodec.canonicalPath]! as Map)['fileId'],
        'snapshot-file',
      );
      final finalReader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await finalReader.readStateSnapshot(appRootId), profileOnlyChange);
      backend.mediaReadNames.clear();
      expect(await finalReader.readStateSnapshot(appRootId), profileOnlyChange);
      expect(backend.mediaReadNames, ['manifest.json', 'snapshot.json']);

      backend.failUploadForName = 'snapshot.json';
      await expectLater(
        finalReader.writeStateSnapshot(
          appRootId: appRootId,
          snapshot: {
            ...profileOnlyChange,
            'settings': {'dailyGoal': 200},
          },
        ),
        throwsA(isA<DriveRequestException>()),
      );
      backend.failUploadForName = null;
      final afterInterruptedUpdate = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(
        await afterInterruptedUpdate.readStateSnapshot(appRootId),
        profileOnlyChange,
      );

      backend.corruptManifestFile(SyncDatasetCodec.canonicalPath);
      final corruptReader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      try {
        await corruptReader.readStateSnapshot(appRootId);
        fail('Expected the corrupt section to be rejected.');
      } on DriveDataIntegrityException catch (error) {
        expect(error.code, 'drive_manifest_sha_mismatch');
        expect(error.quarantine?.sourceFileId, isNotEmpty);
        expect(error.quarantine?.preview, contains('snapshot.json'));
      }
      expect(backend.copiedSourceNames, ['snapshot.json']);
    },
  );

  test(
    'keeps the legacy manifest when canonical migration is interrupted',
    () async {
      final legacySnapshot = <String, Object?>{
        'schemaVersion': 1,
        'updatedAt': '2026-07-29T00:00:00.000Z',
        'profile': <String, Object?>{},
        'settings': <String, Object?>{},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: legacySnapshot,
      )..failUploadForName = 'snapshot.json';
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      await client.readStateSnapshot(appRootId);

      await expectLater(
        client.writeStateSnapshot(
          appRootId: appRootId,
          snapshot: legacySnapshot,
        ),
        throwsA(
          isA<DriveRequestException>().having(
            (error) => error.failure,
            'failure',
            DriveRequestFailure.serviceUnavailable,
          ),
        ),
      );

      expect(backend.manifest['layout'], isNull);
      expect(backend.manifest['files'], contains('state/snapshot.json'));
    },
  );

  test(
    'reads segmented-v1 then switches atomically to one canonical file',
    () async {
      final segmentedSnapshot = <String, Object?>{
        'schemaVersion': 2,
        'updatedAt': '2026-07-31T00:00:00.000Z',
        'profile': {'totalXp': 240},
        'settings': {'dailyGoal': 120, 'importReceipts': <Object?>[]},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final backend = _MemoryDriveBackend.segmented(
        appRootId: appRootId,
        snapshot: segmentedSnapshot,
      );
      final sectionIds = {
        for (final path in SyncDatasetCodec.sectionPaths)
          ((backend.manifest['files']! as Map)[path]! as Map)['fileId'],
      };
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );

      expect(await client.readStateSnapshot(appRootId), segmentedSnapshot);
      backend.uploadedNames.clear();
      await client.writeStateSnapshot(
        appRootId: appRootId,
        snapshot: segmentedSnapshot,
      );

      expect(backend.manifest['layout'], SyncDatasetCodec.canonicalLayout);
      final canonicalFiles = backend.manifest['files']! as Map;
      expect(canonicalFiles.keys, [SyncDatasetCodec.canonicalPath]);
      final canonicalId =
          (canonicalFiles[SyncDatasetCodec.canonicalPath]! as Map)['fileId'];
      expect(canonicalId, isNot(isIn(sectionIds)));
      expect(backend.uploadedNames, ['snapshot.json', 'manifest.json']);
      expect(
        backend._files.values.where((file) => file.name == 'snapshot.json'),
        hasLength(1),
      );
      expect(
        sectionIds.every((fileId) => backend._files.containsKey(fileId)),
        isTrue,
      );

      final next = <String, Object?>{
        ...segmentedSnapshot,
        'customItems': [
          {
            'id': 'item-1',
            'courseId': 'course-en',
            'prompt': 'pitch',
            'answers': ['투구'],
            'updatedAt': '2026-07-31T01:00:00.000Z',
          },
        ],
      };
      final reader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await reader.readStateSnapshot(appRootId), segmentedSnapshot);
      backend.uploadedNames.clear();
      await reader.writeStateSnapshot(appRootId: appRootId, snapshot: next);
      final updatedFiles = backend.manifest['files']! as Map;
      expect(
        (updatedFiles[SyncDatasetCodec.canonicalPath]! as Map)['fileId'],
        canonicalId,
      );
      expect(backend.uploadedNames, ['snapshot.json', 'manifest.json']);
      final finalReader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await finalReader.readStateSnapshot(appRootId), next);
    },
  );

  test(
    'leaves segmented-v1 authoritative when canonical upload is interrupted',
    () async {
      final segmentedSnapshot = <String, Object?>{
        'schemaVersion': 1,
        'updatedAt': '2026-07-31T00:00:00.000Z',
        'profile': <String, Object?>{},
        'settings': <String, Object?>{},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final backend = _MemoryDriveBackend.segmented(
        appRootId: appRootId,
        snapshot: segmentedSnapshot,
      )..failUploadForName = 'snapshot.json';
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await client.readStateSnapshot(appRootId), segmentedSnapshot);

      await expectLater(
        client.writeStateSnapshot(
          appRootId: appRootId,
          snapshot: segmentedSnapshot,
        ),
        throwsA(isA<DriveRequestException>()),
      );
      expect(backend.manifest['layout'], SyncDatasetCodec.layout);
      expect(
        (backend.manifest['files']! as Map).keys,
        containsAll(SyncDatasetCodec.sectionPaths),
      );
      final reader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await reader.readStateSnapshot(appRootId), segmentedSnapshot);
    },
  );

  test(
    'rolls the canonical bytes back when the manifest commit fails',
    () async {
      final original = <String, Object?>{
        'schemaVersion': 2,
        'updatedAt': '2026-07-31T00:00:00.000Z',
        'profile': {'totalXp': 20},
        'settings': <String, Object?>{},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: original,
      );
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await client.readStateSnapshot(appRootId), original);
      await client.writeStateSnapshot(appRootId: appRootId, snapshot: original);
      final canonicalId =
          (((backend.manifest['files']! as Map)[SyncDatasetCodec.canonicalPath]!
                  as Map)['fileId'])
              as String;

      final reader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await reader.readStateSnapshot(appRootId), original);
      backend.failUploadForName = 'manifest.json';
      await expectLater(
        reader.writeStateSnapshot(
          appRootId: appRootId,
          snapshot: {
            ...original,
            'profile': {'totalXp': 999},
          },
        ),
        throwsA(isA<DriveRequestException>()),
      );
      backend.failUploadForName = null;

      final afterFailure = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await afterFailure.readStateSnapshot(appRootId), original);
      expect(
        (((backend.manifest['files']! as Map)[SyncDatasetCodec.canonicalPath]!
            as Map)['fileId']),
        canonicalId,
      );
    },
  );

  test(
    'quarantines a canonical envelope whose internal payload checksum changed',
    () async {
      final original = <String, Object?>{
        'schemaVersion': 2,
        'updatedAt': '2026-07-31T00:00:00.000Z',
        'profile': {'totalXp': 20},
        'settings': <String, Object?>{},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: original,
      );
      final writer = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await writer.readStateSnapshot(appRootId), original);
      await writer.writeStateSnapshot(appRootId: appRootId, snapshot: original);
      backend.corruptCanonicalPayloadAndRefreshManifest();

      final reader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      await expectLater(
        reader.readStateSnapshot(appRootId),
        throwsA(
          isA<DriveDataIntegrityException>()
              .having(
                (error) => error.code,
                'code',
                'drive_snapshot_sha_mismatch',
              )
              .having(
                (error) => error.quarantine?.sourceFileId,
                'quarantine source',
                'snapshot-file',
              ),
        ),
      );
      expect(backend.copiedSourceNames, ['snapshot.json']);
    },
  );

  test(
    'recovers a self-verified canonical write interrupted before manifest commit',
    () async {
      final original = <String, Object?>{
        'schemaVersion': 2,
        'updatedAt': '2026-07-31T00:00:00.000Z',
        'profile': {'totalXp': 20},
        'settings': <String, Object?>{},
        'progress': <Object?>[],
        'customItems': <Object?>[],
        'customItemTombstones': <Object?>[],
        'recentSessions': <Object?>[],
        'activeStudy': null,
      };
      final recovered = <String, Object?>{
        ...original,
        'updatedAt': '2026-07-31T01:00:00.000Z',
        'profile': {'totalXp': 50},
      };
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: original,
      );
      final initialWriter = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await initialWriter.readStateSnapshot(appRootId), original);
      await initialWriter.writeStateSnapshot(
        appRootId: appRootId,
        snapshot: original,
      );
      final canonicalId =
          (((backend.manifest['files']! as Map)[SyncDatasetCodec.canonicalPath]!
                  as Map)['fileId'])
              as String;
      backend.replaceCanonicalSnapshotWithoutManifest(recovered);

      final recoveringWriter = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await recoveringWriter.readStateSnapshot(appRootId), recovered);
      expect(backend.copiedSourceNames, isEmpty);
      await recoveringWriter.writeStateSnapshot(
        appRootId: appRootId,
        snapshot: recovered,
      );

      final repairedEntry =
          (backend.manifest['files']! as Map)[SyncDatasetCodec.canonicalPath]!
              as Map;
      expect(repairedEntry['fileId'], canonicalId);
      final finalReader = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );
      expect(await finalReader.readStateSnapshot(appRootId), recovered);
    },
  );

  test(
    'rejects a manifest overwritten immediately after the final upload',
    () async {
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: snapshot,
      )..overwriteManifestAfterUpload = true;
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
        clock: () => DateTime.utc(2026, 7, 31, 11),
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
      expect(backend.manifest['writerOperationId'], 'other-writer');
    },
  );

  test(
    'rejects an unknown segmented layout without touching remote files',
    () async {
      final backend = _MemoryDriveBackend.legacy(
        appRootId: appRootId,
        snapshot: snapshot,
      )..setManifestLayout('segmented-v2');
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient(backend.handle),
      );

      await expectLater(
        client.readStateSnapshot(appRootId),
        throwsA(
          isA<DriveDataIntegrityException>().having(
            (error) => error.code,
            'code',
            'drive_manifest_newer_layout',
          ),
        ),
      );
      expect(backend.uploadedNames, isEmpty);
      expect(backend.copiedSourceNames, isEmpty);
    },
  );

  group('Drive appDataFolder binding', () {
    const bindingFile = GoogleDriveClient.appDataBindingFileName;
    final existingBinding = <String, Object?>{
      'folderId': 'root-old',
      'folderName': 'WordStudyData',
      'schemaVersion': 1,
      'updatedAt': '2026-08-01T00:00:00.000Z',
    };

    test('returns null when the hidden binding does not exist', () async {
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/drive/v3/files');
          expect(request.url.queryParameters['spaces'], 'appDataFolder');
          expect(request.url.queryParameters['q'], contains(bindingFile));
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response(jsonEncode({'files': []}), 200);
        }),
      );

      expect(await client.readAppDataBinding(), isNull);
      expect(await client.deleteAppDataBinding(), isFalse);
    });

    test(
      'creates the binding in appDataFolder with the compact payload',
      () async {
        final methods = <String>[];
        Map<String, Object?>? metadata;
        Map<String, Object?>? uploaded;
        final client = GoogleDriveClient(
          accessTokenProvider: () async => 'token',
          clock: () => DateTime.utc(2026, 8, 3, 12),
          httpClient: MockClient((request) async {
            methods.add(request.method);
            if (request.method == 'GET' &&
                request.url.path == '/drive/v3/files') {
              expect(request.url.queryParameters['spaces'], 'appDataFolder');
              return http.Response(jsonEncode({'files': []}), 200);
            }
            if (request.method == 'POST' &&
                request.url.path == '/drive/v3/files') {
              metadata = Map<String, Object?>.from(
                jsonDecode(request.body) as Map,
              );
              return http.Response(
                jsonEncode({
                  'id': 'binding-file',
                  'name': bindingFile,
                  'mimeType': 'application/json',
                }),
                200,
              );
            }
            if (request.method == 'PATCH' &&
                request.url.path == '/upload/drive/v3/files/binding-file') {
              expect(request.url.queryParameters['uploadType'], 'media');
              uploaded = Map<String, Object?>.from(
                jsonDecode(request.body) as Map,
              );
              return http.Response('', 200);
            }
            return http.Response('unexpected request', 500);
          }),
        );

        final result = await client.upsertAppDataBinding(
          folderId: 'root-new',
          folderName: 'WordStudyData',
        );

        expect(metadata, {
          'name': bindingFile,
          'parents': ['appDataFolder'],
          'mimeType': 'application/json',
        });
        expect(uploaded, {
          'folderId': 'root-new',
          'folderName': 'WordStudyData',
          'schemaVersion': 1,
          'updatedAt': '2026-08-03T12:00:00.000Z',
        });
        expect(result.folderId, 'root-new');
        expect(result.updatedAt, DateTime.utc(2026, 8, 3, 12));
        expect(methods, ['GET', 'POST', 'PATCH']);
      },
    );

    test('validates then updates the existing file in place', () async {
      var postCount = 0;
      String? patchedPath;
      Map<String, Object?>? uploaded;
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        clock: () => DateTime.utc(2026, 8, 3, 13),
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/drive/v3/files') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'binding-file',
                    'name': bindingFile,
                    'mimeType': 'application/json',
                    'trashed': false,
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'GET' &&
              request.url.path == '/drive/v3/files/binding-file') {
            expect(request.url.queryParameters['alt'], 'media');
            return http.Response(jsonEncode(existingBinding), 200);
          }
          if (request.method == 'POST') {
            postCount++;
            return http.Response('unexpected create', 500);
          }
          if (request.method == 'PATCH') {
            patchedPath = request.url.path;
            uploaded = Map<String, Object?>.from(
              jsonDecode(request.body) as Map,
            );
            return http.Response('', 200);
          }
          return http.Response('unexpected request', 500);
        }),
      );

      await client.upsertAppDataBinding(
        folderId: 'root-updated',
        folderName: 'Renamed root',
      );

      expect(postCount, 0);
      expect(patchedPath, '/upload/drive/v3/files/binding-file');
      expect(uploaded?['folderId'], 'root-updated');
      expect(uploaded?['folderName'], 'Renamed root');
    });

    test(
      'validates and permanently deletes an appDataFolder binding',
      () async {
        var deleteCount = 0;
        final client = GoogleDriveClient(
          accessTokenProvider: () async => 'token',
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/drive/v3/files') {
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'id': 'binding-file',
                      'name': bindingFile,
                      'mimeType': 'application/json',
                    },
                  ],
                }),
                200,
              );
            }
            if (request.method == 'GET' &&
                request.url.path == '/drive/v3/files/binding-file') {
              return http.Response(jsonEncode(existingBinding), 200);
            }
            if (request.method == 'DELETE' &&
                request.url.path == '/drive/v3/files/binding-file') {
              deleteCount++;
              return http.Response('', 204);
            }
            return http.Response('unexpected request', 500);
          }),
        );

        expect(await client.deleteAppDataBinding(), isTrue);
        expect(deleteCount, 1);
      },
    );

    test(
      'rejects duplicate bindings without reading or mutating either',
      () async {
        final methods = <String>[];
        final client = GoogleDriveClient(
          accessTokenProvider: () async => 'token',
          httpClient: MockClient((request) async {
            methods.add(request.method);
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'binding-a',
                    'name': bindingFile,
                    'mimeType': 'application/json',
                  },
                  {
                    'id': 'binding-b',
                    'name': bindingFile,
                    'mimeType': 'application/json',
                  },
                ],
              }),
              200,
            );
          }),
        );

        await expectLater(
          client.readAppDataBinding(),
          throwsA(
            isA<DriveDataIntegrityException>().having(
              (error) => error.code,
              'code',
              'drive_appdata_binding_duplicate',
            ),
          ),
        );
        expect(methods, ['GET']);
      },
    );

    test(
      'rejects corrupt and future-schema payloads before mutation',
      () async {
        for (final testCase in <(Map<String, Object?>, String)>[
          (
            {'folderId': 'root', 'schemaVersion': 1, 'updatedAt': 'not-a-date'},
            'drive_appdata_binding_invalid',
          ),
          (
            {...existingBinding, 'schemaVersion': 2},
            'drive_appdata_binding_newer_schema',
          ),
        ]) {
          final methods = <String>[];
          final client = GoogleDriveClient(
            accessTokenProvider: () async => 'token',
            httpClient: MockClient((request) async {
              methods.add(request.method);
              if (request.url.path == '/drive/v3/files') {
                return http.Response(
                  jsonEncode({
                    'files': [
                      {
                        'id': 'binding-file',
                        'name': bindingFile,
                        'mimeType': 'application/json',
                      },
                    ],
                  }),
                  200,
                );
              }
              return http.Response(jsonEncode(testCase.$1), 200);
            }),
          );

          await expectLater(
            client.upsertAppDataBinding(
              folderId: 'must-not-write',
              folderName: 'WordStudyData',
            ),
            throwsA(
              isA<DriveDataIntegrityException>().having(
                (error) => error.code,
                'code',
                testCase.$2,
              ),
            ),
          );
          expect(methods, ['GET', 'GET']);
        }
      },
    );
  });

  group('drive.file app root discovery', () {
    Map<String, Object?> validManifest(String rootId) => {
      'schemaVersion': 1,
      'datasetVersion': 1,
      'appRootFolderId': rootId,
      'files': <String, Object?>{},
      'updatedAt': '2026-08-03T00:00:00.000Z',
    };

    test('returns the only globally discoverable valid app root', () async {
      final spaces = <String?>[];
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.url.path == '/drive/v3/files') {
            spaces.add(request.url.queryParameters['spaces']);
            final query = request.url.queryParameters['q'] ?? '';
            if (query.contains("name = 'WordStudyData'")) {
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'id': 'root-one',
                      'name': 'WordStudyData',
                      'mimeType': 'application/vnd.google-apps.folder',
                    },
                  ],
                }),
                200,
              );
            }
            expect(query, contains("'root-one' in parents"));
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'manifest-one',
                    'name': 'manifest.json',
                    'mimeType': 'application/json',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/drive/v3/files/manifest-one') {
            return http.Response(jsonEncode(validManifest('root-one')), 200);
          }
          return http.Response('unexpected request', 500);
        }),
      );

      final result = await client.discoverAppRoot();

      expect(result?.appRootFolderId, 'root-one');
      expect(result?.manifestFileId, 'manifest-one');
      expect(spaces, everyElement('drive'));
    });

    test('returns null for zero or multiple valid candidates', () async {
      for (final rootIds in <List<String>>[
        const [],
        const ['root-a', 'root-b'],
      ]) {
        final client = GoogleDriveClient(
          accessTokenProvider: () async => 'token',
          httpClient: MockClient((request) async {
            if (request.url.path == '/drive/v3/files') {
              final query = request.url.queryParameters['q'] ?? '';
              if (query.contains("name = 'WordStudyData'")) {
                return http.Response(
                  jsonEncode({
                    'files': [
                      for (final rootId in rootIds)
                        {
                          'id': rootId,
                          'name': 'WordStudyData',
                          'mimeType': 'application/vnd.google-apps.folder',
                        },
                    ],
                  }),
                  200,
                );
              }
              final rootId = rootIds.singleWhere(query.contains);
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'id': 'manifest-$rootId',
                      'name': 'manifest.json',
                      'mimeType': 'application/json',
                    },
                  ],
                }),
                200,
              );
            }
            final manifestId = request.url.path.split('/').last;
            final rootId = manifestId.replaceFirst('manifest-', '');
            return http.Response(jsonEncode(validManifest(rootId)), 200);
          }),
        );

        expect(await client.discoverAppRoot(), isNull);
      }
    });

    test('ignores damaged candidates and never mutates Drive', () async {
      final methods = <String>[];
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          methods.add(request.method);
          if (request.url.path == '/drive/v3/files') {
            final query = request.url.queryParameters['q'] ?? '';
            if (query.contains("name = 'WordStudyData'")) {
              return http.Response(
                jsonEncode({
                  'files': [
                    {
                      'id': 'root-future',
                      'name': 'WordStudyData',
                      'mimeType': 'application/vnd.google-apps.folder',
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'manifest-future',
                    'name': 'manifest.json',
                    'mimeType': 'application/json',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({...validManifest('root-future'), 'schemaVersion': 99}),
            200,
          );
        }),
      );

      expect(await client.discoverAppRoot(), isNull);
      expect(methods, everyElement('GET'));
    });
  });

  test('retention only trashes unreferenced JSON older than 30 days', () async {
    final trashed = <String>[];
    final remoteManifest = {
      'schemaVersion': 1,
      'datasetVersion': 4,
      'layout': SyncDatasetCodec.layout,
      'appRootFolderId': appRootId,
      'files': {
        'state/profile.json': {
          'fileId': 'referenced',
          'revision': '1',
          'sha256': 'a' * 64,
        },
      },
    };
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      clock: () => DateTime.utc(2026, 9),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final query = request.url.queryParameters['q'] ?? '';
        if (request.method == 'GET' && path == '/drive/v3/files') {
          if (query.contains("name = 'manifest.json'")) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'manifest'},
                ],
              }),
              200,
            );
          }
          if (query.contains("name = 'state'")) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'state-folder'},
                ],
              }),
              200,
            );
          }
          if (query.contains("name = 'content'")) {
            return http.Response(jsonEncode({'files': []}), 200);
          }
          if (query.contains("'state-folder' in parents")) {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'referenced',
                    'name': 'profile.json',
                    'mimeType': 'application/json',
                    'size': '20',
                    'modifiedTime': '2026-06-01T00:00:00.000Z',
                    'trashed': false,
                  },
                  {
                    'id': 'old-orphan',
                    'name': 'profile.v3.old.json',
                    'mimeType': 'application/json',
                    'size': '120',
                    'modifiedTime': '2026-07-01T00:00:00.000Z',
                    'trashed': false,
                  },
                  {
                    'id': 'recent-orphan',
                    'name': 'profile.v4.recent.json',
                    'mimeType': 'application/json',
                    'size': '80',
                    'modifiedTime': '2026-08-20T00:00:00.000Z',
                    'trashed': false,
                  },
                ],
              }),
              200,
            );
          }
        }
        if (request.method == 'GET' && path == '/drive/v3/files/manifest') {
          return http.Response(jsonEncode(remoteManifest), 200);
        }
        if (request.method == 'PATCH' && path == '/drive/v3/files/old-orphan') {
          trashed.add('old-orphan');
          return http.Response(
            jsonEncode({'id': 'old-orphan', 'trashed': true}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final inventory = await client.inspectRetention(appRootId: appRootId);

    expect(inventory.items, hasLength(2));
    expect(inventory.eligibleCount, 1);
    expect(inventory.eligibleBytes, 120);
    expect(
      inventory.items
          .singleWhere((item) => item.fileId == 'recent-orphan')
          .eligibleForCleanup,
      isFalse,
    );

    final result = await client.trashRetentionItems(
      appRootId: appRootId,
      inventory: inventory,
      selectedFileIds: {'old-orphan'},
    );
    expect(result.trashedCount, 1);
    expect(result.trashedBytes, 120);
    expect(trashed, ['old-orphan']);
  });

  test('retention refuses cleanup after manifest changes', () async {
    var datasetVersion = 4;
    var patchCount = 0;
    Map<String, Object?> remoteManifest() => {
      'schemaVersion': 1,
      'datasetVersion': datasetVersion,
      'layout': SyncDatasetCodec.layout,
      'appRootFolderId': appRootId,
      'files': {
        'state/profile.json': {
          'fileId': 'referenced',
          'revision': '$datasetVersion',
          'sha256': 'b' * 64,
        },
      },
    };
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      clock: () => DateTime.utc(2026, 9),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final query = request.url.queryParameters['q'] ?? '';
        if (request.method == 'GET' && path == '/drive/v3/files') {
          if (query.contains("name = 'manifest.json'")) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'manifest'},
                ],
              }),
              200,
            );
          }
          if (query.contains("name = 'state'")) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'state-folder'},
                ],
              }),
              200,
            );
          }
          if (query.contains("name = 'content'")) {
            return http.Response(jsonEncode({'files': []}), 200);
          }
          return http.Response(
            jsonEncode({
              'files': [
                {
                  'id': 'old-orphan',
                  'name': 'profile.v3.old.json',
                  'mimeType': 'application/json',
                  'size': '120',
                  'modifiedTime': '2026-07-01T00:00:00.000Z',
                  'trashed': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' && path == '/drive/v3/files/manifest') {
          return http.Response(jsonEncode(remoteManifest()), 200);
        }
        if (request.method == 'PATCH') {
          patchCount++;
          return http.Response('', 200);
        }
        return http.Response('not found', 404);
      }),
    );
    final inventory = await client.inspectRetention(appRootId: appRootId);
    datasetVersion++;

    await expectLater(
      client.trashRetentionItems(
        appRootId: appRootId,
        inventory: inventory,
        selectedFileIds: {'old-orphan'},
      ),
      throwsA(
        isA<DriveDataIntegrityException>().having(
          (error) => error.code,
          'code',
          'drive_retention_conflict',
        ),
      ),
    );
    expect(patchCount, 0);
  });

  test('creates a new Drive app root with the Sprache folder name', () async {
    final createdNames = <String>[];
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          final name = RegExp(r"name = '([^']+)'").firstMatch(query)?.group(1);
          if (name == 'manifest.json') {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'manifest-file'},
                ],
              }),
              200,
            );
          }
          if (const {
            'content',
            'state',
            'backups',
            'quarantine',
          }.contains(name)) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': '$name-folder'},
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'files': []}), 200);
        }
        if (request.method == 'POST' && request.url.path == '/drive/v3/files') {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final name = body['name']! as String;
          createdNames.add(name);
          return http.Response(jsonEncode({'id': 'new-root'}), 200);
        }
        return http.Response('unexpected request', 500);
      }),
    );

    final bootstrap = await client.ensureAppRoot('selected-parent');

    expect(createdNames, ['Sprache']);
    expect(bootstrap.appRootFolderId, 'new-root');
    expect(bootstrap.appRootFolderName, 'Sprache');
  });

  test(
    'reuses a legacy WordStudyData root instead of duplicating it',
    () async {
      final postRequests = <http.Request>[];
      final client = GoogleDriveClient(
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') postRequests.add(request);
          if (request.method == 'GET' &&
              request.url.path == '/drive/v3/files') {
            final query = request.url.queryParameters['q'] ?? '';
            final name = RegExp(
              r"name = '([^']+)'",
            ).firstMatch(query)?.group(1);
            if (name == 'WordStudyData') {
              return http.Response(
                jsonEncode({
                  'files': [
                    {'id': 'legacy-root'},
                  ],
                }),
                200,
              );
            }
            if (name == 'manifest.json') {
              return http.Response(
                jsonEncode({
                  'files': [
                    {'id': 'manifest-file'},
                  ],
                }),
                200,
              );
            }
            if (const {
              'content',
              'state',
              'backups',
              'quarantine',
            }.contains(name)) {
              return http.Response(
                jsonEncode({
                  'files': [
                    {'id': '$name-folder'},
                  ],
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'files': []}), 200);
          }
          return http.Response('unexpected request', 500);
        }),
      );

      final bootstrap = await client.ensureAppRoot('selected-parent');

      expect(postRequests, isEmpty);
      expect(bootstrap.appRootFolderId, 'legacy-root');
      expect(bootstrap.appRootFolderName, 'WordStudyData');
    },
  );

  test('reuses a linked app root without creating a nested root', () async {
    final requestedPaths = <String>[];
    final client = GoogleDriveClient(
      accessTokenProvider: () async => 'token',
      httpClient: MockClient((request) async {
        requestedPaths.add('${request.method} ${request.url}');
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/existing-root') {
          return http.Response(
            jsonEncode({
              'id': 'existing-root',
              'name': 'WordStudyData',
              'mimeType': 'application/vnd.google-apps.folder',
              'trashed': false,
            }),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          final name = RegExp(r"name = '([^']+)'").firstMatch(query)?.group(1);
          if (name == 'manifest.json') {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'manifest-file'},
                ],
              }),
              200,
            );
          }
          if (const {
            'content',
            'state',
            'backups',
            'quarantine',
          }.contains(name)) {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': '$name-folder'},
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'files': []}), 200);
        }
        return http.Response('unexpected request', 500);
      }),
    );

    final bootstrap = await client.reuseAppRoot(
      'existing-root',
      expectedFolderName: 'WordStudyData',
    );

    expect(bootstrap.appRootFolderId, 'existing-root');
    expect(bootstrap.appRootFolderName, 'WordStudyData');
    expect(bootstrap.manifestFileId, 'manifest-file');
    expect(requestedPaths.where((path) => path.startsWith('POST ')), isEmpty);
    expect(requestedPaths.any((path) => path.contains('imports')), isFalse);
  });
}

class _MemoryDriveBackend {
  _MemoryDriveBackend._(this.appRootId);

  factory _MemoryDriveBackend.legacy({
    required String appRootId,
    required Map<String, Object?> snapshot,
  }) {
    final backend = _MemoryDriveBackend._(appRootId);
    backend._addFolder('state', appRootId, id: 'state-folder');
    backend._addFolder('content', appRootId, id: 'content-folder');
    backend._addFolder('quarantine', appRootId, id: 'quarantine-folder');
    final snapshotId = backend._addJson(
      'snapshot.json',
      'state-folder',
      snapshot,
      id: 'snapshot-file',
    );
    final snapshotFile = backend._files[snapshotId]!;
    backend._addJson('manifest.json', appRootId, {
      'schemaVersion': 1,
      'datasetVersion': 1,
      'appRootFolderId': appRootId,
      'files': {
        'state/snapshot.json': {
          'fileId': snapshotId,
          'revision': '${snapshotFile.version}',
          'sha256': sha256.convert(snapshotFile.bytes).toString(),
          'updatedAt': snapshotFile.modifiedAt,
        },
      },
      'updatedAt': snapshotFile.modifiedAt,
    }, id: 'manifest-file');
    return backend;
  }

  factory _MemoryDriveBackend.segmented({
    required String appRootId,
    required Map<String, Object?> snapshot,
  }) {
    final backend = _MemoryDriveBackend._(appRootId);
    final stateFolderId = backend._addFolder(
      'state',
      appRootId,
      id: 'state-folder',
    );
    final contentFolderId = backend._addFolder(
      'content',
      appRootId,
      id: 'content-folder',
    );
    backend._addFolder('quarantine', appRootId, id: 'quarantine-folder');
    final sections = const SyncDatasetCodec().split(snapshot);
    final manifestFiles = <String, Object?>{};
    var sectionSequence = 0;
    for (final entry in sections.entries) {
      final name = entry.key.split('/').last;
      final parentId = entry.key.startsWith('content/')
          ? contentFolderId
          : stateFolderId;
      final fileId = backend._addJson(
        name,
        parentId,
        entry.value,
        id: 'section-${sectionSequence++}',
      );
      final file = backend._files[fileId]!;
      manifestFiles[entry.key] = {
        'fileId': fileId,
        'revision': '${file.version}',
        'sha256': sha256.convert(file.bytes).toString(),
        'updatedAt': file.modifiedAt,
      };
    }
    backend._addJson('manifest.json', appRootId, {
      'schemaVersion': 1,
      'datasetVersion': 7,
      'layout': SyncDatasetCodec.layout,
      'appRootFolderId': appRootId,
      'files': manifestFiles,
      'updatedAt': '2026-07-31T00:00:00.000Z',
    }, id: 'manifest-file');
    return backend;
  }

  final String appRootId;
  final Map<String, _MemoryDriveFile> _files = {};
  final List<String> uploadedNames = [];
  final List<String> copiedSourceNames = [];
  final List<String> mediaReadNames = [];
  final List<int> mediaReadByteLengths = [];
  var _sequence = 0;
  String? failUploadForName;
  String? failUploadForNamePrefix;
  bool overwriteManifestAfterUpload = false;

  Map<String, Object?> get manifest {
    final file = _files.values.singleWhere(
      (candidate) => candidate.name == 'manifest.json',
    );
    return Map<String, Object?>.from(
      jsonDecode(utf8.decode(file.bytes)) as Map,
    );
  }

  void corruptManifestFile(String path) {
    final files = manifest['files']! as Map<String, Object?>;
    final entry = files[path]! as Map<String, Object?>;
    final file = _files[entry['fileId']]!;
    file.bytes = utf8.encode('{"corrupt":true}');
  }

  void corruptCanonicalPayloadAndRefreshManifest() {
    final manifestFile = _files.values.singleWhere(
      (candidate) => candidate.name == 'manifest.json',
    );
    final nextManifest = manifest;
    final files = nextManifest['files']! as Map<String, Object?>;
    final entry =
        files[SyncDatasetCodec.canonicalPath]! as Map<String, Object?>;
    final snapshotFile = _files[entry['fileId']]!;
    final envelope = Map<String, Object?>.from(
      jsonDecode(utf8.decode(snapshotFile.bytes)) as Map,
    );
    final snapshot = Map<String, Object?>.from(envelope['snapshot']! as Map)
      ..['profile'] = {'totalXp': 777};
    envelope['snapshot'] = snapshot;
    snapshotFile
      ..bytes = utf8.encode(jsonEncode(envelope))
      ..version += 1;
    entry
      ..['revision'] = '${snapshotFile.version}'
      ..['sha256'] = sha256.convert(snapshotFile.bytes).toString()
      ..['updatedAt'] = snapshotFile.modifiedAt;
    manifestFile
      ..bytes = utf8.encode(jsonEncode(nextManifest))
      ..version += 1;
  }

  void replaceCanonicalSnapshotWithoutManifest(Map<String, Object?> snapshot) {
    final files = manifest['files']! as Map<String, Object?>;
    final entry =
        files[SyncDatasetCodec.canonicalPath]! as Map<String, Object?>;
    final snapshotFile = _files[entry['fileId']]!;
    final payloadSha = sha256
        .convert(utf8.encode(jsonEncode(snapshot)))
        .toString();
    snapshotFile
      ..bytes = utf8.encode(
        jsonEncode({
          'format': 'sprache-canonical-drive-snapshot-v1',
          'snapshotSchemaVersion': snapshot['schemaVersion'],
          'payloadSha256': payloadSha,
          'writerOperationId': 'writer-interrupted-test',
          'writtenAt': '2026-07-31T01:00:00.000Z',
          'snapshot': snapshot,
        }),
      )
      ..version += 1;
  }

  void setManifestLayout(String layout) {
    final file = _files.values.singleWhere(
      (candidate) => candidate.name == 'manifest.json',
    );
    final value = manifest..['layout'] = layout;
    file
      ..bytes = utf8.encode(jsonEncode(value))
      ..version += 1;
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/drive/v3/files') {
      final query = request.url.queryParameters['q'] ?? '';
      final parent = RegExp(
        r"'([^']+)' in parents",
      ).firstMatch(query)?.group(1);
      final name = RegExp(r"name = '([^']+)'").firstMatch(query)?.group(1);
      final mimeType = RegExp(
        r"mimeType = '([^']+)'",
      ).firstMatch(query)?.group(1);
      final matches = _files.values.where(
        (file) =>
            file.parentId == parent &&
            file.name == name &&
            (mimeType == null || file.mimeType == mimeType),
      );
      return http.Response(
        jsonEncode({
          'files': [
            for (final file in matches)
              {'id': file.id, 'name': file.name, 'mimeType': file.mimeType},
          ],
        }),
        200,
      );
    }

    if (request.method == 'POST' && path == '/drive/v3/files') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final id = 'created-${_sequence++}';
      _files[id] = _MemoryDriveFile(
        id: id,
        name: body['name']! as String,
        parentId: (body['parents']! as List).first! as String,
        mimeType: body['mimeType']! as String,
        bytes: const [],
      );
      return http.Response(jsonEncode({'id': id, 'name': body['name']}), 200);
    }

    if (request.method == 'PATCH' &&
        path.startsWith('/upload/drive/v3/files/')) {
      final id = path.split('/').last;
      final file = _files[id]!;
      if (file.name == failUploadForName ||
          (failUploadForNamePrefix != null &&
              file.name.startsWith(failUploadForNamePrefix!))) {
        return http.Response('temporary failure', 503);
      }
      file
        ..bytes = request.bodyBytes
        ..version += 1;
      uploadedNames.add(file.name);
      if (file.name == 'manifest.json' && overwriteManifestAfterUpload) {
        final overwritten = Map<String, Object?>.from(
          jsonDecode(utf8.decode(file.bytes)) as Map,
        )..['writerOperationId'] = 'other-writer';
        file
          ..bytes = utf8.encode(jsonEncode(overwritten))
          ..version += 1;
      }
      return http.Response('', 200);
    }

    if (request.method == 'POST' && path.endsWith('/copy')) {
      final sourceId = path.split('/')[4];
      final source = _files[sourceId]!;
      copiedSourceNames.add(source.name);
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final id = 'copy-${_sequence++}';
      final copy = _MemoryDriveFile(
        id: id,
        name: body['name']! as String,
        parentId: (body['parents']! as List).first! as String,
        mimeType: source.mimeType,
        bytes: List<int>.from(source.bytes),
      );
      _files[id] = copy;
      return http.Response(jsonEncode({'id': id, 'name': copy.name}), 200);
    }

    if (request.method == 'GET' && path.startsWith('/drive/v3/files/')) {
      final id = path.split('/').last;
      final file = _files[id];
      if (file == null) return http.Response('not found', 404);
      if (request.url.queryParameters['alt'] == 'media') {
        mediaReadNames.add(file.name);
        mediaReadByteLengths.add(file.bytes.length);
        return http.Response.bytes(file.bytes, 200);
      }
      return http.Response(
        jsonEncode({
          'id': file.id,
          'version': '${file.version}',
          'modifiedTime': file.modifiedAt,
          'size': '${file.bytes.length}',
          'mimeType': file.mimeType,
          'trashed': false,
        }),
        200,
      );
    }
    return http.Response('unsupported ${request.method} $path', 404);
  }

  String _addFolder(String name, String parentId, {required String id}) {
    _files[id] = _MemoryDriveFile(
      id: id,
      name: name,
      parentId: parentId,
      mimeType: 'application/vnd.google-apps.folder',
      bytes: const [],
    );
    return id;
  }

  String _addJson(
    String name,
    String parentId,
    Map<String, Object?> content, {
    required String id,
  }) {
    _files[id] = _MemoryDriveFile(
      id: id,
      name: name,
      parentId: parentId,
      mimeType: 'application/json',
      bytes: utf8.encode(jsonEncode(content)),
    );
    return id;
  }
}

class _MemoryDriveFile {
  _MemoryDriveFile({
    required this.id,
    required this.name,
    required this.parentId,
    required this.mimeType,
    required this.bytes,
  });

  final String id;
  final String name;
  final String parentId;
  final String mimeType;
  List<int> bytes;
  int version = 1;

  String get modifiedAt => '2026-07-29T00:00:0$version.000Z';
}
