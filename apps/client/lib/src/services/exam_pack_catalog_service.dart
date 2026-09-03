import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../domain/exam_pack.dart';

const defaultExamPackCatalogUrl =
    'https://raw.githubusercontent.com/youkdonghun/Sprache/main/'
    'exam-packs/catalog.json';

class ExamPackCatalog {
  const ExamPackCatalog({required this.updatedAt, required this.packs});

  final DateTime? updatedAt;
  final List<ExamPackDescriptor> packs;
}

class ExamPackDescriptor {
  const ExamPackDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.version,
    required this.revision,
    required this.questionCount,
    required this.sizeBytes,
    required this.sha256,
    required this.path,
    required this.license,
    required this.attribution,
  });

  final String id;
  final String title;
  final String description;
  final String version;
  final int revision;
  final int questionCount;
  final int sizeBytes;
  final String sha256;
  final String path;
  final String license;
  final String attribution;
}

class ExamPackCatalogException extends FormatException {
  const ExamPackCatalogException(super.message);
}

class DownloadedExamPack {
  const DownloadedExamPack({required this.descriptor, required this.pack});

  final ExamPackDescriptor descriptor;
  final ExamPack pack;
}

class ExamPackCatalogService {
  ExamPackCatalogService({
    required this.catalogUri,
    http.Client? client,
    this.catalogTimeout = const Duration(seconds: 12),
    this.downloadTimeout = const Duration(seconds: 60),
    this.maxCatalogBytes = 512 * 1024,
    this.maxPackBytes = 20 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  final Uri catalogUri;
  final http.Client _client;
  final Duration catalogTimeout;
  final Duration downloadTimeout;
  final int maxCatalogBytes;
  final int maxPackBytes;

  void close() => _client.close();

  Future<ExamPackCatalog> fetchCatalog() async {
    _ensureHttps(catalogUri);
    final response = await _get(catalogUri, catalogTimeout);
    if (response.statusCode != 200) {
      throw ExamPackCatalogException(
        '시험팩 목록을 불러오지 못했습니다. (${response.statusCode})',
      );
    }
    if (response.bodyBytes.length > maxCatalogBytes) {
      throw const ExamPackCatalogException('시험팩 목록이 허용 크기를 넘었습니다.');
    }
    final json = _decode(response.bodyBytes, '시험팩 목록');
    if (_int(json, 'schemaVersion') != 1) {
      throw const ExamPackCatalogException('지원하지 않는 시험팩 목록 형식입니다.');
    }
    final rawPacks = json['packs'];
    if (rawPacks is! List<Object?> || rawPacks.length > 100) {
      throw const ExamPackCatalogException('시험팩 목록이 올바르지 않습니다.');
    }
    final ids = <String>{};
    final packs = <ExamPackDescriptor>[];
    for (final raw in rawPacks) {
      if (raw is! Map) {
        throw const ExamPackCatalogException('시험팩 정보가 올바르지 않습니다.');
      }
      final value = Map<String, Object?>.from(raw);
      final id = _string(value, 'id', 80);
      if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(id) ||
          !ids.add(id)) {
        throw ExamPackCatalogException('시험팩 ID가 올바르지 않습니다: $id');
      }
      if (_string(value, 'language', 16) != 'en') {
        throw const ExamPackCatalogException('현재 시험팩은 영어만 지원합니다.');
      }
      final path = _string(value, 'path', 240);
      _validatePath(path);
      final sha = _string(value, 'sha256', 64).toLowerCase();
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
        throw ExamPackCatalogException('$id 시험팩 확인 정보가 올바르지 않습니다.');
      }
      final count = _int(value, 'questionCount');
      final size = _int(value, 'sizeBytes');
      final revision = _int(value, 'revision');
      if (count < 1 ||
          count > 5000 ||
          size < 1 ||
          size > maxPackBytes ||
          revision < 1) {
        throw ExamPackCatalogException('$id 시험팩 크기 또는 문제 수가 올바르지 않습니다.');
      }
      packs.add(
        ExamPackDescriptor(
          id: id,
          title: _string(value, 'title', 100),
          description: _string(value, 'description', 300),
          version: _string(value, 'version', 40),
          revision: revision,
          questionCount: count,
          sizeBytes: size,
          sha256: sha,
          path: path,
          license: _string(value, 'license', 120),
          attribution: _string(value, 'attribution', 500),
        ),
      );
    }
    return ExamPackCatalog(
      updatedAt: DateTime.tryParse(
        json['updatedAt']?.toString() ?? '',
      )?.toUtc(),
      packs: List.unmodifiable(packs),
    );
  }

  Future<DownloadedExamPack> downloadPack(ExamPackDescriptor descriptor) async {
    final uri = _resolve(descriptor.path);
    final response = await _get(uri, downloadTimeout);
    if (response.statusCode != 200) {
      throw ExamPackCatalogException('시험팩을 받지 못했습니다. (${response.statusCode})');
    }
    final bytes = response.bodyBytes;
    if (bytes.length != descriptor.sizeBytes || bytes.length > maxPackBytes) {
      throw const ExamPackCatalogException('시험팩 파일 크기가 목록과 다릅니다.');
    }
    if (sha256.convert(bytes).toString() != descriptor.sha256) {
      throw const ExamPackCatalogException('시험팩 무결성 확인에 실패했습니다.');
    }
    final pack = ExamPack.fromJson(_decode(bytes, '시험팩'));
    if (pack.id != descriptor.id ||
        pack.title != descriptor.title ||
        pack.version != descriptor.version ||
        pack.revision != descriptor.revision ||
        pack.questions.length != descriptor.questionCount ||
        pack.license != descriptor.license ||
        pack.attribution != descriptor.attribution) {
      throw const ExamPackCatalogException('시험팩 내용이 목록 정보와 다릅니다.');
    }
    return DownloadedExamPack(descriptor: descriptor, pack: pack);
  }

  Future<http.Response> _get(Uri uri, Duration timeout) async {
    try {
      return await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const ExamPackCatalogException('연결 시간이 초과됐습니다.');
    } on http.ClientException {
      throw const ExamPackCatalogException('인터넷 연결을 확인해 주세요.');
    }
  }

  Map<String, Object?> _decode(Uint8List bytes, String label) {
    try {
      final value = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (value is! Map) throw const FormatException();
      return Map<String, Object?>.from(value);
    } on Object {
      throw ExamPackCatalogException('$label JSON을 해석하지 못했습니다.');
    }
  }

  Uri _resolve(String path) {
    _validatePath(path);
    final uri = catalogUri.resolve(path);
    _ensureHttps(uri);
    if (uri.host != catalogUri.host) {
      throw const ExamPackCatalogException('시험팩 주소가 목록과 다른 서버를 가리킵니다.');
    }
    return uri;
  }

  void _validatePath(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        path.startsWith('/') ||
        path.contains('\\') ||
        !path.endsWith('.json') ||
        uri.pathSegments.any((segment) => segment.isEmpty || segment == '..')) {
      throw const ExamPackCatalogException('시험팩 경로가 안전하지 않습니다.');
    }
  }

  void _ensureHttps(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const ExamPackCatalogException('시험팩은 안전한 HTTPS 주소만 지원합니다.');
    }
  }

  String _string(Map<String, Object?> json, String key, int maximum) {
    final value = json[key];
    if (value is! String ||
        value.trim().isEmpty ||
        value.runes.length > maximum) {
      throw ExamPackCatalogException('$key 값이 올바르지 않습니다.');
    }
    return value.trim();
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw ExamPackCatalogException('$key 값은 정수여야 합니다.');
    }
    return value.toInt();
  }
}
