import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleOAuthException implements Exception {
  const GoogleOAuthException({
    required this.operation,
    required this.statusCode,
    this.code,
    this.description,
  });

  final String operation;
  final int statusCode;
  final String? code;
  final String? description;

  @override
  String toString() {
    final details = [
      if (code != null && code!.isNotEmpty) code!,
      if (description != null && description!.isNotEmpty) description!,
    ].join(': ');
    return '$operation failed ($statusCode)'
        '${details.isEmpty ? '' : ' · $details'}';
  }
}

class DesktopGoogleTokenResponse {
  const DesktopGoogleTokenResponse({
    required this.accessToken,
    required this.expiresIn,
    this.refreshToken,
    this.idToken,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final int expiresIn;
}

abstract interface class DesktopGoogleTokenBroker {
  Future<void> ensureReady();

  Future<DesktopGoogleTokenResponse> exchangeAuthorizationCode({
    required String authorizationCode,
    required String codeVerifier,
    required String redirectUri,
  });

  Future<DesktopGoogleTokenResponse> refresh({required String refreshToken});
}

class RailwayDesktopGoogleTokenBroker implements DesktopGoogleTokenBroker {
  RailwayDesktopGoogleTokenBroker({
    required String apiBaseUrl,
    http.Client? httpClient,
  }) : _apiBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _httpClient = httpClient ?? http.Client();

  final String _apiBaseUrl;
  final http.Client _httpClient;

  @override
  Future<void> ensureReady() async {
    late final http.Response response;
    try {
      response = await _httpClient
          .get(Uri.parse('$_apiBaseUrl/health'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const GoogleOAuthException(
        operation: 'Railway Google OAuth preflight',
        statusCode: 503,
        code: 'oauth_broker_unreachable',
        description: 'Railway API is temporarily unreachable.',
      );
    }
    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleOAuthException(
        operation: 'Railway Google OAuth preflight',
        statusCode: response.statusCode,
        code: 'oauth_broker_health_failed',
        description: 'Railway health check failed.',
      );
    }
    if (decoded?['desktopOAuthBroker'] != 'ready') {
      throw GoogleOAuthException(
        operation: 'Railway Google OAuth preflight',
        statusCode: 503,
        code: 'oauth_broker_not_configured',
        description: decoded?['desktopOAuthBroker'] == null
            ? 'Railway API must be updated before Windows Google login.'
            : 'Desktop Google OAuth is not configured on Railway.',
      );
    }
  }

  @override
  Future<DesktopGoogleTokenResponse> exchangeAuthorizationCode({
    required String authorizationCode,
    required String codeVerifier,
    required String redirectUri,
  }) {
    return _request(
      operation: 'Railway Google token exchange',
      payload: {
        'grantType': 'authorization_code',
        'authorizationCode': authorizationCode,
        'codeVerifier': codeVerifier,
        'redirectUri': redirectUri,
      },
    );
  }

  @override
  Future<DesktopGoogleTokenResponse> refresh({required String refreshToken}) {
    return _request(
      operation: 'Railway Google token refresh',
      payload: {'grantType': 'refresh_token', 'refreshToken': refreshToken},
    );
  }

  Future<DesktopGoogleTokenResponse> _request({
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse('$_apiBaseUrl/v1/oauth/google/desktop/token'),
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw GoogleOAuthException(
        operation: operation,
        statusCode: 503,
        code: 'oauth_broker_unreachable',
        description: 'Railway API is temporarily unreachable.',
      );
    }
    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleOAuthException(
        operation: operation,
        statusCode: response.statusCode,
        code: decoded?['error']?.toString(),
        description:
            decoded?['description']?.toString() ??
            decoded?['message']?.toString(),
      );
    }
    final accessToken = decoded?['accessToken'];
    final expiresIn = decoded?['expiresIn'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        expiresIn is! num ||
        expiresIn <= 0) {
      throw GoogleOAuthException(
        operation: operation,
        statusCode: 502,
        code: 'oauth_broker_invalid_response',
        description: 'Railway returned an invalid Google token response.',
      );
    }
    return DesktopGoogleTokenResponse(
      accessToken: accessToken,
      refreshToken: decoded?['refreshToken'] as String?,
      idToken: decoded?['idToken'] as String?,
      expiresIn: expiresIn.toInt(),
    );
  }

  Map<String, Object?>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
