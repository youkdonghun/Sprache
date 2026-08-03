class WebGoogleAuthorization {
  const WebGoogleAuthorization({
    required this.accessToken,
    required this.expiresAt,
  });

  final String accessToken;
  final DateTime expiresAt;
}

class GoogleWebOAuthClient {
  GoogleWebOAuthClient({required this.clientId});

  final String clientId;

  WebGoogleAuthorization? get currentAuthorization => null;

  Future<WebGoogleAuthorization> authorize({bool forceAccountChoice = false}) {
    throw UnsupportedError(
      'Google Web OAuth is available only in a browser ($clientId).',
    );
  }

  Future<String?> pickDriveFolder({
    required String accessToken,
    required String apiKey,
  }) {
    throw UnsupportedError('Google Picker is available only in a browser.');
  }

  Future<void> disconnect() async {}
}
