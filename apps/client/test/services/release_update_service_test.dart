import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/services/release_update_service.dart';

void main() {
  group('ReleaseVersion', () {
    test('compares semantic versions by numeric component', () {
      expect(
        ReleaseVersion.tryParse(
          '1.10.0',
        )!.compareTo(ReleaseVersion.tryParse('1.9.99')!),
        greaterThan(0),
      );
      expect(ReleaseVersion.tryParse('1.2'), isNull);
    });
  });

  group('ReleaseUpdateService', () {
    test('reports a newer release and requests a fresh manifest', () async {
      late Uri requestedUri;
      late Map<String, String> requestedHeaders;
      final service = ReleaseUpdateService(
        manifestUri: Uri.parse('https://sprache6.github.io/app/release.json'),
        client: MockClient((request) async {
          requestedUri = request.url;
          requestedHeaders = request.headers;
          return _jsonResponse(_manifest());
        }),
      );

      final result = await service.check(
        currentVersion: '1.37.1',
        platform: 'windows',
      );

      expect(result.updateAvailable, isTrue);
      expect(result.manifest.version.toString(), '1.38.0');
      expect(result.artifact?.kind, 'installer');
      expect(requestedUri.queryParameters['check'], isNotEmpty);
      expect(requestedHeaders['cache-control'], 'no-cache');
    });

    test('does not report the same semantic version as an update', () async {
      final service = ReleaseUpdateService(
        manifestUri: Uri.parse('https://sprache6.github.io/app/release.json'),
        client: MockClient((_) async => _jsonResponse(_manifest())),
      );

      final result = await service.check(
        currentVersion: '1.38.0',
        platform: 'android',
      );

      expect(result.updateAvailable, isFalse);
      expect(result.canRedownloadCurrentAndroidApk, isTrue);
    });

    test('detects a newer build within the same semantic version', () async {
      final service = ReleaseUpdateService(
        manifestUri: Uri.parse(
          'https://github.com/youkdonghun/Sprache/releases/latest/download/release.json',
        ),
        client: MockClient((_) async => _jsonResponse(_manifest())),
      );

      final result = await service.check(
        currentVersion: '1.38.0',
        currentBuildNumber: 67,
        platform: 'android',
      );

      expect(result.updateAvailable, isTrue);
      expect(result.currentBuildNumber, 67);
    });

    test('rejects untrusted artifact hosts', () async {
      final payload = _manifest();
      final artifacts = payload['artifacts']! as Map<String, Object?>;
      final windows = artifacts['windows']! as Map<String, Object?>;
      windows['url'] = 'https://example.com/Sprache-Windows.exe';
      final service = ReleaseUpdateService(
        manifestUri: Uri.parse('https://sprache6.github.io/app/release.json'),
        client: MockClient((_) async => _jsonResponse(payload)),
      );

      await expectLater(
        service.check(currentVersion: '1.37.1', platform: 'windows'),
        throwsA(
          isA<ReleaseUpdateException>().having(
            (error) => error.message,
            'message',
            contains('손상'),
          ),
        ),
      );
    });

    test('rejects missing download integrity metadata', () {
      expect(
        () => ReleaseArtifact.fromJson('android', {
          'kind': 'apk',
          'url':
              'https://github.com/youkdonghun/Sprache/releases/download/v1.38.0/app.apk',
          'fileName': 'app.apk',
          'sizeBytes': 100,
        }),
        throwsFormatException,
      );
    });
  });
}

http.Response _jsonResponse(Map<String, Object?> payload) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(payload)),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, Object?> _manifest() => <String, Object?>{
  'schemaVersion': 1,
  'version': '1.38.0',
  'buildNumber': 68,
  'publishedAt': '2026-09-02T00:00:00Z',
  'title': 'Sprache 1.38.0',
  'notes': <String>['앱 안에서 업데이트를 확인할 수 있습니다.'],
  'releasePageUrl':
      'https://github.com/youkdonghun/Sprache/releases/tag/v1.38.0',
  'artifacts': <String, Object?>{
    'windows': <String, Object?>{
      'kind': 'installer',
      'url':
          'https://github.com/youkdonghun/Sprache/releases/download/v1.38.0/Sprache-Windows-Setup-1.38.0-google-x64.exe',
      'fileName': 'Sprache-Windows-Setup-1.38.0-google-x64.exe',
      'sha256': _hashA,
      'sizeBytes': 1024,
    },
    'android': <String, Object?>{
      'kind': 'apk',
      'url':
          'https://github.com/youkdonghun/Sprache/releases/download/v1.38.0/Sprache-Android-1.38.0-google-debug-signed.apk',
      'fileName': 'Sprache-Android-1.38.0-google-debug-signed.apk',
      'sha256': _hashB,
      'sizeBytes': 2048,
    },
    'pwa': <String, Object?>{
      'kind': 'web',
      'url': 'https://sprache6.github.io/app/',
    },
  },
};

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
