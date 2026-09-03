import '../services/language_pack_catalog_service.dart';
import '../services/exam_pack_catalog_service.dart';
import '../services/release_update_service.dart';

class AppConfig {
  const AppConfig({
    required this.googleAndroidClientId,
    required this.googleDesktopClientId,
    required this.googleServerClientId,
    required this.appEnvironment,
    required this.mockMode,
    this.googleAppleClientId = '',
    this.googleWebClientId = '',
    this.googlePickerApiKey = '',
    this.appVersion = '개발 빌드',
    this.appBuildNumber = 0,
    this.privacyPolicyUrl = '',
    this.releaseManifestUrl = defaultReleaseManifestUrl,
    this.languagePackCatalogUrl = defaultLanguagePackCatalogUrl,
    this.examPackCatalogUrl = defaultExamPackCatalogUrl,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    googleAndroidClientId: String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID'),
    googleDesktopClientId: String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID'),
    googleAppleClientId: String.fromEnvironment('GOOGLE_APPLE_CLIENT_ID'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    googlePickerApiKey: String.fromEnvironment('GOOGLE_PICKER_API_KEY'),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    appEnvironment: String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    mockMode: bool.fromEnvironment('ENABLE_MOCK_MODE', defaultValue: true),
    appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '개발 빌드'),
    appBuildNumber: int.fromEnvironment(
      'RELEASE_BUILD_NUMBER',
      defaultValue: 0,
    ),
    privacyPolicyUrl: String.fromEnvironment(
      'PRIVACY_POLICY_URL',
      defaultValue: 'https://sprache6.github.io/privacy/',
    ),
    releaseManifestUrl: String.fromEnvironment(
      'RELEASE_MANIFEST_URL',
      defaultValue: defaultReleaseManifestUrl,
    ),
    languagePackCatalogUrl: String.fromEnvironment(
      'LANGUAGE_PACK_CATALOG_URL',
      defaultValue: defaultLanguagePackCatalogUrl,
    ),
    examPackCatalogUrl: String.fromEnvironment(
      'EXAM_PACK_CATALOG_URL',
      defaultValue: defaultExamPackCatalogUrl,
    ),
  );

  final String googleAndroidClientId;
  final String googleDesktopClientId;
  final String googleAppleClientId;
  final String googleWebClientId;
  final String googlePickerApiKey;
  final String googleServerClientId;
  final String appEnvironment;
  final bool mockMode;
  final String appVersion;
  final int appBuildNumber;
  final String privacyPolicyUrl;
  final String releaseManifestUrl;
  final String languagePackCatalogUrl;
  final String examPackCatalogUrl;

  bool get hasDesktopGoogleCredentials => googleDesktopClientId.isNotEmpty;
  bool get hasAndroidGoogleCredentials =>
      googleAndroidClientId.isNotEmpty && googleServerClientId.isNotEmpty;
  bool get hasAppleGoogleCredentials => googleAppleClientId.isNotEmpty;
  bool get hasWebGoogleCredentials => googleWebClientId.isNotEmpty;
}
