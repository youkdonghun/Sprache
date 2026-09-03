import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../domain/language.dart';

const defaultLanguagePackCatalogUrl =
    'https://raw.githubusercontent.com/youkdonghun/Sprache/main/'
    'language-packs/catalog.json';

const languagePackSourceIdPrefix = 'language-pack:';

String languagePackSourceId(String packId) =>
    '$languagePackSourceIdPrefix$packId';

class LanguagePackCatalog {
  const LanguagePackCatalog({required this.updatedAt, required this.packs});

  final DateTime? updatedAt;
  final List<LanguagePackDescriptor> packs;
}

class LanguagePackDescriptor {
  const LanguagePackDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.version,
    required this.revision,
    required this.itemCount,
    required this.sizeBytes,
    required this.sha256,
    required this.path,
    required this.license,
    required this.attribution,
  });

  final String id;
  final String title;
  final String description;
  final LanguageTag language;
  final String version;
  final int revision;
  final int itemCount;
  final int sizeBytes;
  final String sha256;
  final String path;
  final String license;
  final String attribution;

  String get sourceId => languagePackSourceId(id);
}

class DownloadedLanguagePack {
  const DownloadedLanguagePack({
    required this.descriptor,
    required this.fileName,
    required this.bytes,
  });

  final LanguagePackDescriptor descriptor;
  final String fileName;
  final Uint8List bytes;
}

class LanguagePackCatalogException extends FormatException {
  const LanguagePackCatalogException(super.message);
}

class LanguagePackCatalogService {
  LanguagePackCatalogService({
    required this.catalogUri,
    http.Client? client,
    this.catalogTimeout = const Duration(seconds: 12),
    this.downloadTimeout = const Duration(seconds: 60),
    this.maxCatalogBytes = 1024 * 1024,
    this.maxPackBytes = 20 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  final Uri catalogUri;
  final http.Client _client;
  final Duration catalogTimeout;
  final Duration downloadTimeout;
  final int maxCatalogBytes;
  final int maxPackBytes;

  void close() => _client.close();

  Future<LanguagePackCatalog> fetchCatalog() async {
    _ensureHttpsUri(catalogUri, label: '언어팩 목록 주소');
    final response = await _get(catalogUri, timeout: catalogTimeout);
    if (response.statusCode != 200) {
      throw LanguagePackCatalogException(
        '언어팩 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요. '
        '(${response.statusCode})',
      );
    }
    if (response.bodyBytes.length > maxCatalogBytes) {
      throw const LanguagePackCatalogException('언어팩 목록 파일이 허용 크기를 넘었습니다.');
    }
    final decoded = _decodeObject(response.bodyBytes, label: '언어팩 목록');
    if (_integer(decoded['schemaVersion'], field: 'schemaVersion') != 1) {
      throw const LanguagePackCatalogException('지원하지 않는 언어팩 목록 형식입니다.');
    }
    final rawPacks = decoded['packs'];
    if (rawPacks is! List<Object?>) {
      throw const LanguagePackCatalogException('언어팩 목록의 packs 배열이 올바르지 않습니다.');
    }
    if (rawPacks.length > 200) {
      throw const LanguagePackCatalogException('언어팩 목록은 최대 200개까지 지원합니다.');
    }
    final seenIds = <String>{};
    final packs = <LanguagePackDescriptor>[];
    for (final (index, rawPack) in rawPacks.indexed) {
      if (rawPack is! Map) {
        throw LanguagePackCatalogException('${index + 1}번째 언어팩 정보가 올바르지 않습니다.');
      }
      final descriptor = _parseDescriptor(
        Map<String, Object?>.from(rawPack),
        index: index,
      );
      if (!seenIds.add(descriptor.id)) {
        throw LanguagePackCatalogException('중복된 언어팩 ID입니다: ${descriptor.id}');
      }
      packs.add(descriptor);
    }
    packs.sort((left, right) {
      final languageOrder = left.language.code.compareTo(right.language.code);
      return languageOrder != 0
          ? languageOrder
          : left.title.compareTo(right.title);
    });
    return LanguagePackCatalog(
      updatedAt: _optionalDate(decoded['updatedAt'], field: 'updatedAt'),
      packs: List.unmodifiable(packs),
    );
  }

  Future<DownloadedLanguagePack> downloadPack(
    LanguagePackDescriptor descriptor,
  ) async {
    final packUri = _resolvePackUri(descriptor.path);
    final response = await _get(packUri, timeout: downloadTimeout);
    if (response.statusCode != 200) {
      throw LanguagePackCatalogException(
        '“${descriptor.title}”을 다운로드하지 못했습니다. '
        '잠시 후 다시 시도해 주세요. (${response.statusCode})',
      );
    }
    final bytes = response.bodyBytes;
    if (bytes.length > maxPackBytes) {
      throw const LanguagePackCatalogException('언어팩은 최대 20MB까지 받을 수 있습니다.');
    }
    if (bytes.length != descriptor.sizeBytes) {
      throw const LanguagePackCatalogException(
        '학습 자료가 아직 준비 중이에요. 잠시 후 다시 시도해 주세요.',
      );
    }
    final digest = sha256.convert(bytes).toString();
    if (digest != descriptor.sha256) {
      throw const LanguagePackCatalogException(
        '언어팩 무결성 확인에 실패했습니다. 기존 학습 자료는 변경하지 않았습니다.',
      );
    }
    final decoded = _decodeObject(bytes, label: '언어팩');
    final normalized = _validateAndNormalizePack(
      decoded,
      descriptor: descriptor,
      sourceUri: packUri,
    );
    return DownloadedLanguagePack(
      descriptor: descriptor,
      fileName: '${descriptor.id}-${descriptor.version}.json',
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(normalized))),
    );
  }

  Future<http.Response> _get(Uri uri, {required Duration timeout}) async {
    try {
      return await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const LanguagePackCatalogException(
        '연결 시간이 초과되었습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
      );
    } on http.ClientException {
      throw const LanguagePackCatalogException(
        '학습 자료 목록을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.',
      );
    }
  }

  LanguagePackDescriptor _parseDescriptor(
    Map<String, Object?> json, {
    required int index,
  }) {
    final id = _requiredString(json, 'id', maxLength: 80);
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(id)) {
      throw LanguagePackCatalogException(
        '${index + 1}번째 언어팩 ID는 영문 소문자·숫자·점·밑줄·하이픈만 사용할 수 있습니다.',
      );
    }
    final languageCode = _requiredString(json, 'language', maxLength: 16);
    final language = LanguageTag.values.firstWhere(
      (value) => value.code == languageCode,
      orElse: () => throw LanguagePackCatalogException(
        '지원하지 않는 언어팩 언어입니다: $languageCode',
      ),
    );
    final path = _requiredString(json, 'path', maxLength: 240);
    _validateRelativePath(path);
    final digest = _requiredString(json, 'sha256', maxLength: 64).toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw LanguagePackCatalogException('$id 학습 자료의 확인 정보가 올바르지 않아요.');
    }
    final itemCount = _integer(json['itemCount'], field: 'itemCount');
    final sizeBytes = _integer(json['sizeBytes'], field: 'sizeBytes');
    final revision = _integer(json['revision'], field: 'revision');
    if (itemCount < 1 || itemCount > 20000) {
      throw LanguagePackCatalogException('$id 언어팩 항목 수는 1~20,000개여야 합니다.');
    }
    if (sizeBytes < 1 || sizeBytes > maxPackBytes) {
      throw LanguagePackCatalogException('$id 언어팩 크기가 허용 범위를 벗어났습니다.');
    }
    if (revision < 1) {
      throw LanguagePackCatalogException('$id 언어팩 revision은 1 이상이어야 합니다.');
    }
    return LanguagePackDescriptor(
      id: id,
      title: _requiredString(json, 'title', maxLength: 80),
      description: _requiredString(json, 'description', maxLength: 240),
      language: language,
      version: _requiredString(json, 'version', maxLength: 40),
      revision: revision,
      itemCount: itemCount,
      sizeBytes: sizeBytes,
      sha256: digest,
      path: path,
      license: _requiredString(json, 'license', maxLength: 120),
      attribution: _requiredString(json, 'attribution', maxLength: 500),
    );
  }

  Map<String, Object?> _validateAndNormalizePack(
    Map<String, Object?> pack, {
    required LanguagePackDescriptor descriptor,
    required Uri sourceUri,
  }) {
    if (_integer(pack['schemaVersion'], field: 'schemaVersion') != 1) {
      throw const LanguagePackCatalogException('지원하지 않는 언어팩 파일 형식입니다.');
    }
    final checks = <String, String>{
      'id': descriptor.id,
      'title': descriptor.title,
      'description': descriptor.description,
      'language': descriptor.language.code,
      'version': descriptor.version,
      'license': descriptor.license,
      'attribution': descriptor.attribution,
    };
    for (final entry in checks.entries) {
      if (_requiredString(pack, entry.key, maxLength: 500) != entry.value) {
        throw LanguagePackCatalogException('언어팩의 ${entry.key} 값이 목록 정보와 다릅니다.');
      }
    }
    if (_integer(pack['revision'], field: 'revision') != descriptor.revision) {
      throw const LanguagePackCatalogException('언어팩 revision이 목록 정보와 다릅니다.');
    }
    final rawItems = pack['items'];
    if (rawItems is! List<Object?> || rawItems.length != descriptor.itemCount) {
      throw const LanguagePackCatalogException('언어팩 항목 수가 목록 정보와 다릅니다.');
    }
    final ids = <String>{};
    final normalizedItems = <Map<String, Object?>>[];
    for (final (index, rawItem) in rawItems.indexed) {
      if (rawItem is! Map) {
        throw LanguagePackCatalogException('${index + 1}번째 언어팩 항목이 올바르지 않습니다.');
      }
      final item = Map<String, Object?>.from(rawItem);
      final itemId = _requiredString(item, 'id', maxLength: 160);
      if (!ids.add(itemId)) {
        throw LanguagePackCatalogException('언어팩 안에 중복 ID가 있습니다: $itemId');
      }
      final type = _requiredString(item, 'type', maxLength: 16);
      if (type != 'word' && type != 'sentence') {
        throw LanguagePackCatalogException(
          '${index + 1}번째 항목 type은 word 또는 sentence여야 합니다.',
        );
      }
      _requiredString(item, 'term', maxLength: 20000);
      _requiredString(item, 'meaning', maxLength: 20000);
      if (type == 'sentence') {
        final tokens = _requiredString(
          item,
          'sentence_tokens',
          maxLength: 20000,
        );
        if (!tokens.contains('|')) {
          throw LanguagePackCatalogException(
            '${index + 1}번째 문장에는 |로 구분한 sentence_tokens가 필요합니다.',
          );
        }
      }
      final rowLanguage = item['language'];
      if (rowLanguage != null && rowLanguage != descriptor.language.code) {
        throw LanguagePackCatalogException('${index + 1}번째 항목 언어가 팩 언어와 다릅니다.');
      }
      if (descriptor.language == LanguageTag.english) {
        // A spelling-derived Hangul value is not a pronunciation standard.
        // Managed English packs always defer to device TTS, even if an old or
        // third-party pack still contains one of the legacy reading columns.
        for (final key in const {
          'reading',
          'korean_pronunciation',
          'korean_reading',
          'hangul',
          'ko_pronunciation',
          '한국어_발음',
          '한글_발음',
        }) {
          item.remove(key);
        }
      }
      normalizedItems.add(item);
    }
    return {
      'schemaVersion': 1,
      'defaults': {
        'language': descriptor.language.code,
        'subject_id': 'language:${descriptor.language.code.toLowerCase()}',
        'distribution_key': 'lang:${descriptor.language.code.toLowerCase()}',
        'source_name': descriptor.title,
        'license': descriptor.license,
        'source_version': descriptor.version,
        'source_id': descriptor.sourceId,
        'source_url': sourceUri.toString(),
        'attribution': descriptor.attribution,
        'content_version': descriptor.revision,
      },
      'items': normalizedItems,
    };
  }

  Uri _resolvePackUri(String path) {
    _validateRelativePath(path);
    final resolved = catalogUri.resolve(path);
    _ensureHttpsUri(resolved, label: '언어팩 주소');
    if (resolved.host != catalogUri.host) {
      throw const LanguagePackCatalogException('학습 자료 주소를 확인할 수 없어요.');
    }
    return resolved;
  }

  void _validateRelativePath(String path) {
    final parsed = Uri.tryParse(path);
    if (parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority ||
        path.startsWith('/') ||
        path.contains('\\') ||
        parsed.pathSegments.any(
          (segment) => segment.isEmpty || segment == '..',
        ) ||
        !path.toLowerCase().endsWith('.json')) {
      throw const LanguagePackCatalogException(
        '언어팩 path는 저장소 안의 안전한 JSON 상대 경로여야 합니다.',
      );
    }
  }

  void _ensureHttpsUri(Uri uri, {required String label}) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw LanguagePackCatalogException('$label는 안전한 HTTPS 주소여야 합니다.');
    }
  }

  Map<String, Object?> _decodeObject(List<int> bytes, {required String label}) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map) {
        throw const FormatException();
      }
      return Map<String, Object?>.from(decoded);
    } on Object {
      throw LanguagePackCatalogException('$label JSON을 해석하지 못했습니다.');
    }
  }

  String _requiredString(
    Map<String, Object?> json,
    String field, {
    required int maxLength,
  }) {
    final value = json[field];
    if (value is! String ||
        value.trim().isEmpty ||
        value.runes.length > maxLength) {
      throw LanguagePackCatalogException('$field 값이 없거나 너무 깁니다.');
    }
    return value.trim();
  }

  int _integer(Object? value, {required String field}) {
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw LanguagePackCatalogException('$field 값은 정수여야 합니다.');
    }
    return value.toInt();
  }

  DateTime? _optionalDate(Object? value, {required String field}) {
    if (value == null) return null;
    if (value is! String || DateTime.tryParse(value) == null) {
      throw LanguagePackCatalogException('$field 값은 ISO 8601 날짜여야 합니다.');
    }
    return DateTime.parse(value).toUtc();
  }
}
