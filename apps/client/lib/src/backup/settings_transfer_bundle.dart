import 'dart:convert';

import '../domain/device_preferences.dart';
import '../domain/study_preferences.dart';

class SettingsTransferException implements Exception {
  const SettingsTransferException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SettingsTransferBundle {
  const SettingsTransferBundle({
    required this.appPreferences,
    required this.devicePreferences,
    required this.exportedAt,
  });

  final StudyPreferences appPreferences;
  final DevicePreferences devicePreferences;
  final DateTime exportedAt;

  Map<String, Object?> toJson() => {
    'format': 'sprache-settings-v1',
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'appPreferences': appPreferences.toJson(),
    'devicePreferences': devicePreferences.toJson(),
  };
}

class SettingsTransferCodec {
  const SettingsTransferCodec();

  static const maxBytes = 512 * 1024;

  String encode(SettingsTransferBundle bundle) =>
      const JsonEncoder.withIndent('  ').convert(bundle.toJson());

  SettingsTransferBundle decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const SettingsTransferException('설정 파일은 512KB 이하여야 합니다.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const SettingsTransferException('올바른 JSON 설정 파일이 아닙니다.');
    }
    if (decoded is! Map) {
      throw const SettingsTransferException('설정 파일의 최상위 값이 올바르지 않습니다.');
    }
    final json = Map<String, Object?>.from(decoded);
    const allowed = {
      'format',
      'exportedAt',
      'appPreferences',
      'devicePreferences',
    };
    if (json.keys.any((key) => !allowed.contains(key)) ||
        json['format'] != 'sprache-settings-v1') {
      throw const SettingsTransferException(
        '학습 콘텐츠가 없는 Sprache 설정 전용 파일만 사용할 수 있습니다.',
      );
    }
    final exportedAt = DateTime.tryParse(json['exportedAt'] as String? ?? '');
    final app = json['appPreferences'];
    final device = json['devicePreferences'];
    if (exportedAt == null || app is! Map || device is! Map) {
      throw const SettingsTransferException('설정 파일의 필수 항목이 없습니다.');
    }
    try {
      return SettingsTransferBundle(
        appPreferences: StudyPreferences.fromJson(
          Map<String, Object?>.from(app),
        ),
        devicePreferences: DevicePreferences.fromJson(
          Map<String, Object?>.from(device),
        ),
        exportedAt: exportedAt.toUtc(),
      );
    } on Object {
      throw const SettingsTransferException('설정 값의 형식이 올바르지 않습니다.');
    }
  }
}
