import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sprache/src/services/exam_pack_catalog_service.dart';

void main() {
  final catalogUri = Uri.parse('https://example.test/exam-packs/catalog.json');

  Map<String, Object?> pack() => {
    'schemaVersion': 1,
    'id': 'exam-test',
    'title': '시험 테스트',
    'description': '다운로드 검증',
    'language': 'en',
    'version': '1.0.0',
    'revision': 1,
    'publishedAt': '2026-09-03T00:00:00Z',
    'license': 'test',
    'attribution': 'test fixture',
    'disclaimer': 'test only',
    'stimuli': <Object?>[],
    'questions': [
      {
        'id': 'q1',
        'part': 5,
        'prompt': 'Choose the answer.',
        'choices': ['A', 'B', 'C', 'D'],
        'correctIndex': 0,
        'explanation': '문법상 A가 정답입니다.',
        'choiceExplanations': ['A 근거', 'B 근거', 'C 근거', 'D 근거'],
        'skill': '문법',
        'difficulty': 'foundation',
      },
    ],
  };

  Map<String, Object?> catalog(List<int> bytes, {String? hash}) => {
    'schemaVersion': 1,
    'updatedAt': '2026-09-03T00:00:00Z',
    'packs': [
      {
        'id': 'exam-test',
        'title': '시험 테스트',
        'description': '다운로드 검증',
        'language': 'en',
        'version': '1.0.0',
        'revision': 1,
        'questionCount': 1,
        'sizeBytes': bytes.length,
        'sha256': hash ?? sha256.convert(bytes).toString(),
        'path': 'packs/exam-test.json',
        'license': 'test',
        'attribution': 'test fixture',
      },
    ],
  };

  test('downloads a pack after size and SHA-256 verification', () async {
    final packBytes = utf8.encode(jsonEncode(pack()));
    final catalogBytes = utf8.encode(jsonEncode(catalog(packBytes)));
    final service = ExamPackCatalogService(
      catalogUri: catalogUri,
      client: MockClient((request) async {
        if (request.url == catalogUri) {
          return http.Response.bytes(catalogBytes, 200);
        }
        return http.Response.bytes(packBytes, 200);
      }),
    );

    final descriptor = (await service.fetchCatalog()).packs.single;
    final downloaded = await service.downloadPack(descriptor);

    expect(downloaded.pack.id, 'exam-test');
    expect(downloaded.pack.questions.single.explanation, isNotEmpty);
  });

  test('rejects modified pack bytes', () async {
    final expectedBytes = utf8.encode(jsonEncode(pack()));
    final changed = pack()..['description'] = '변조된 문제팩';
    final changedBytes = utf8.encode(jsonEncode(changed));
    final catalogBytes = utf8.encode(jsonEncode(catalog(expectedBytes)));
    final service = ExamPackCatalogService(
      catalogUri: catalogUri,
      client: MockClient(
        (request) async => request.url == catalogUri
            ? http.Response.bytes(catalogBytes, 200)
            : http.Response.bytes(changedBytes, 200),
      ),
    );

    final descriptor = (await service.fetchCatalog()).packs.single;
    expect(
      () => service.downloadPack(descriptor),
      throwsA(isA<ExamPackCatalogException>()),
    );
  });
}
