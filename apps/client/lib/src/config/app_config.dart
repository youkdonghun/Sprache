class AppConfig {
  const AppConfig({
    required this.googleAndroidClientId,
    required this.googleDesktopClientId,
    required this.googleServerClientId,
    required this.appEnvironment,
    required this.mockMode,
    this.googleDesktopClientSecret = '',
    this.googleAppleClientId = '',
    this.googleWebClientId = '',
    this.googlePickerApiKey = '',
    this.appVersion = '개발 빌드',
    this.privacyPolicyUrl = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    googleAndroidClientId: String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID'),
    googleDesktopClientId: String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID'),
    googleDesktopClientSecret: String.fromEnvironment(
      'GOOGLE_DESKTOP_CLIENT_SECRET',
    ),
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
    privacyPolicyUrl: String.fromEnvironment(
      'PRIVACY_POLICY_URL',
      defaultValue: 'https://sprache6.github.io/privacy/',
    ),
  );

  final String googleAndroidClientId;
  final String googleDesktopClientId;
  final String googleDesktopClientSecret;
  final String googleAppleClientId;
  final String googleWebClientId;
  final String googlePickerApiKey;
  final String googleServerClientId;
  final String appEnvironment;
  final bool mockMode;
  final String appVersion;
  final String privacyPolicyUrl;

  bool get hasDesktopGoogleCredentials =>
      googleDesktopClientId.isNotEmpty && googleDesktopClientSecret.isNotEmpty;
  bool get hasAndroidGoogleCredentials =>
      googleAndroidClientId.isNotEmpty && googleServerClientId.isNotEmpty;
  bool get hasAppleGoogleCredentials => googleAppleClientId.isNotEmpty;
  bool get hasWebGoogleCredentials => googleWebClientId.isNotEmpty;
}
