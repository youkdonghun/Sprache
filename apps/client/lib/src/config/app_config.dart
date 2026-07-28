class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.googleAndroidClientId,
    required this.googleDesktopClientId,
    required this.googleServerClientId,
    required this.appEnvironment,
    required this.mockMode,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    ),
    googleAndroidClientId: String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID'),
    googleDesktopClientId: String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID'),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    appEnvironment: String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    mockMode: bool.fromEnvironment('ENABLE_MOCK_MODE', defaultValue: true),
  );

  final String apiBaseUrl;
  final String googleAndroidClientId;
  final String googleDesktopClientId;
  final String googleServerClientId;
  final String appEnvironment;
  final bool mockMode;

  bool get hasDesktopGoogleCredentials => googleDesktopClientId.isNotEmpty;
  bool get hasAndroidGoogleCredentials =>
      googleAndroidClientId.isNotEmpty && googleServerClientId.isNotEmpty;
}
