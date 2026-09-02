import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const defaultReleaseManifestUrl =
    'https://sprache6.github.io/app/release.json';

class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static ReleaseVersion? tryParse(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(value.trim());
    if (match == null) return null;
    return ReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(ReleaseVersion other) {
    final majorOrder = major.compareTo(other.major);
    if (majorOrder != 0) return majorOrder;
    final minorOrder = minor.compareTo(other.minor);
    if (minorOrder != 0) return minorOrder;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

class ReleaseArtifact {
  const ReleaseArtifact({
    required this.platform,
    required this.kind,
    required this.url,
    this.fileName,
    this.sha256,
    this.sizeBytes,
  });

  final String platform;
  final String kind;
  final Uri url;
  final String? fileName;
  final String? sha256;
  final int? sizeBytes;

  bool get isDownload => kind == 'installer' || kind == 'apk';

  factory ReleaseArtifact.fromJson(String platform, Map<String, Object?> json) {
    final kind = json['kind']?.toString().trim() ?? '';
    final url = _safeReleaseUri(json['url']);
    if (!const {'installer', 'apk', 'web', 'releasePage'}.contains(kind)) {
      throw const FormatException('지원하지 않는 업데이트 파일 형식입니다.');
    }

    final rawFileName = json['fileName']?.toString().trim();
    final rawSha256 = json['sha256']?.toString().trim().toLowerCase();
    final rawSize = json['sizeBytes'];
    final sizeBytes = rawSize is int ? rawSize : int.tryParse('$rawSize');
    if (kind == 'installer' || kind == 'apk') {
      if (rawFileName == null ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$').hasMatch(rawFileName) ||
          rawSha256 == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(rawSha256) ||
          sizeBytes == null ||
          sizeBytes <= 0 ||
          sizeBytes > 512 * 1024 * 1024) {
        throw const FormatException('업데이트 파일 검증 정보가 올바르지 않습니다.');
      }
    }

    return ReleaseArtifact(
      platform: platform,
      kind: kind,
      url: url,
      fileName: rawFileName,
      sha256: rawSha256,
      sizeBytes: sizeBytes,
    );
  }
}

class ReleaseManifest {
  const ReleaseManifest({
    required this.version,
    required this.buildNumber,
    required this.publishedAt,
    required this.title,
    required this.notes,
    required this.releasePageUrl,
    required this.artifacts,
  });

  final ReleaseVersion version;
  final int buildNumber;
  final DateTime publishedAt;
  final String title;
  final List<String> notes;
  final Uri releasePageUrl;
  final Map<String, ReleaseArtifact> artifacts;

  ReleaseArtifact? artifactFor(String platform) => artifacts[platform];

  factory ReleaseManifest.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('지원하지 않는 업데이트 정보 형식입니다.');
    }
    final version = ReleaseVersion.tryParse(json['version']?.toString() ?? '');
    final buildNumber = json['buildNumber'] is int
        ? json['buildNumber']! as int
        : int.tryParse('${json['buildNumber']}');
    final publishedAt = DateTime.tryParse(json['publishedAt']?.toString() ?? '');
    final title = json['title']?.toString().trim() ?? '';
    final releasePageUrl = _safeReleaseUri(json['releasePageUrl']);
    if (version == null ||
        buildNumber == null ||
        buildNumber <= 0 ||
        publishedAt == null ||
        title.isEmpty ||
        title.length > 120) {
      throw const FormatException('업데이트 버전 정보가 올바르지 않습니다.');
    }

    final rawNotes = json['notes'];
    final notes = rawNotes is List
        ? rawNotes
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty && value.length <= 300)
              .take(8)
              .toList(growable: false)
        : const <String>[];
    final rawArtifacts = json['artifacts'];
    if (rawArtifacts is! Map) {
      throw const FormatException('업데이트 파일 목록이 없습니다.');
    }
    final artifacts = <String, ReleaseArtifact>{};
    for (final entry in rawArtifacts.entries) {
      final platform = entry.key.toString();
      final value = entry.value;
      if (value is Map) {
        artifacts[platform] = ReleaseArtifact.fromJson(
          platform,
          Map<String, Object?>.from(value),
        );
      }
    }
    return ReleaseManifest(
      version: version,
      buildNumber: buildNumber,
      publishedAt: publishedAt.toUtc(),
      title: title,
      notes: List.unmodifiable(notes),
      releasePageUrl: releasePageUrl,
      artifacts: Map.unmodifiable(artifacts),
    );
  }
}

class ReleaseUpdateCheck {
  const ReleaseUpdateCheck({
    required this.currentVersion,
    required this.manifest,
    required this.platform,
    required this.updateAvailable,
  });

  final ReleaseVersion currentVersion;
  final ReleaseManifest manifest;
  final String platform;
  final bool updateAvailable;

  ReleaseArtifact? get artifact => manifest.artifactFor(platform);
}

class ReleaseUpdateException implements Exception {
  const ReleaseUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReleaseUpdateService {
  ReleaseUpdateService({http.Client? client, required this.manifestUri})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Uri manifestUri;

  Future<ReleaseUpdateCheck> check({
    required String currentVersion,
    required String platform,
  }) async {
    final parsedCurrent = ReleaseVersion.tryParse(currentVersion);
    if (parsedCurrent == null) {
      throw const ReleaseUpdateException('개발 빌드는 정식 버전과 비교할 수 없습니다.');
    }
    try {
      final response = await _client
          .get(
            manifestUri.replace(
              queryParameters: {
                ...manifestUri.queryParameters,
                'check': DateTime.now().millisecondsSinceEpoch.toString(),
              },
            ),
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw ReleaseUpdateException(
          '업데이트 서버가 ${response.statusCode} 응답을 반환했습니다.',
        );
      }
      if (response.bodyBytes.length > 128 * 1024) {
        throw const ReleaseUpdateException('업데이트 정보가 허용 크기를 넘었습니다.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException('업데이트 정보가 JSON 객체가 아닙니다.');
      }
      final manifest = ReleaseManifest.fromJson(
        Map<String, Object?>.from(decoded),
      );
      return ReleaseUpdateCheck(
        currentVersion: parsedCurrent,
        manifest: manifest,
        platform: platform,
        updateAvailable: manifest.version.compareTo(parsedCurrent) > 0,
      );
    } on ReleaseUpdateException {
      rethrow;
    } on TimeoutException {
      throw const ReleaseUpdateException('업데이트 확인 시간이 초과됐습니다.');
    } on FormatException {
      throw const ReleaseUpdateException('업데이트 정보가 손상됐습니다.');
    } catch (_) {
      throw const ReleaseUpdateException('인터넷 연결을 확인한 뒤 다시 시도해 주세요.');
    }
  }
}

Uri _safeReleaseUri(Object? value) {
  final uri = Uri.tryParse(value?.toString().trim() ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      !const {
        'github.com',
        'sprache6.github.io',
      }.contains(uri.host.toLowerCase())) {
    throw const FormatException('허용되지 않은 업데이트 주소입니다.');
  }
  return uri;
}
