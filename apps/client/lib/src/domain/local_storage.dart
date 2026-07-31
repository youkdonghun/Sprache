import 'accessibility_input_profile.dart';

enum LocalStorageLocationKind { fileSystemPath, androidDocumentTree }

class LocalStorageSettings {
  const LocalStorageSettings({
    this.locationId,
    this.displayName,
    this.locationKind = LocalStorageLocationKind.fileSystemPath,
    this.lastSavedAt,
    this.lastArchiveSha256,
    this.lastArchiveBytes,
    this.awaitingExistingArchiveDecision = false,
    this.accessibilityInputProfile = const AccessibilityInputProfile(),
  });

  final String? locationId;
  final String? displayName;
  final LocalStorageLocationKind locationKind;
  final DateTime? lastSavedAt;
  final String? lastArchiveSha256;
  final int? lastArchiveBytes;
  final bool awaitingExistingArchiveDecision;
  final AccessibilityInputProfile accessibilityInputProfile;

  bool get configured =>
      locationId != null &&
      locationId!.trim().isNotEmpty &&
      displayName != null &&
      displayName!.trim().isNotEmpty;

  LocalStorageSettings copyWith({
    String? locationId,
    String? displayName,
    LocalStorageLocationKind? locationKind,
    DateTime? lastSavedAt,
    String? lastArchiveSha256,
    int? lastArchiveBytes,
    bool? awaitingExistingArchiveDecision,
    AccessibilityInputProfile? accessibilityInputProfile,
  }) {
    return LocalStorageSettings(
      locationId: locationId ?? this.locationId,
      displayName: displayName ?? this.displayName,
      locationKind: locationKind ?? this.locationKind,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      lastArchiveSha256: lastArchiveSha256 ?? this.lastArchiveSha256,
      lastArchiveBytes: lastArchiveBytes ?? this.lastArchiveBytes,
      awaitingExistingArchiveDecision:
          awaitingExistingArchiveDecision ??
          this.awaitingExistingArchiveDecision,
      accessibilityInputProfile:
          accessibilityInputProfile ?? this.accessibilityInputProfile,
    );
  }

  Map<String, Object?> toJson() => {
    if (locationId != null) 'locationId': locationId,
    if (displayName != null) 'displayName': displayName,
    'locationKind': locationKind.name,
    if (lastSavedAt != null)
      'lastSavedAt': lastSavedAt!.toUtc().toIso8601String(),
    if (lastArchiveSha256 != null) 'lastArchiveSha256': lastArchiveSha256,
    if (lastArchiveBytes != null) 'lastArchiveBytes': lastArchiveBytes,
    if (awaitingExistingArchiveDecision)
      'awaitingExistingArchiveDecision': true,
    'accessibilityInputProfile': accessibilityInputProfile.toJson(),
  };

  factory LocalStorageSettings.fromJson(Map<String, Object?> json) {
    final rawKind = json['locationKind'];
    final kind = LocalStorageLocationKind.values.firstWhere(
      (value) => value.name == rawKind,
      orElse: () => LocalStorageLocationKind.fileSystemPath,
    );
    final rawBytes = json['lastArchiveBytes'];
    return LocalStorageSettings(
      locationId: _optionalText(json['locationId']),
      displayName: _optionalText(json['displayName']),
      locationKind: kind,
      lastSavedAt: switch (json['lastSavedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      lastArchiveSha256: _optionalText(json['lastArchiveSha256']),
      lastArchiveBytes: rawBytes is num && rawBytes.isFinite
          ? rawBytes.toInt()
          : null,
      awaitingExistingArchiveDecision:
          json['awaitingExistingArchiveDecision'] == true,
      accessibilityInputProfile: switch (json['accessibilityInputProfile']) {
        final Map value => AccessibilityInputProfile.fromJson(
          Map<String, Object?>.from(value),
        ),
        _ => const AccessibilityInputProfile(),
      },
    );
  }
}

String? _optionalText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
