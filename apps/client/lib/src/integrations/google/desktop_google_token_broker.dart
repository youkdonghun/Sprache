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

/// Exchanges installed-app OAuth grants directly with Google's token endpoint.
///
/// A desktop OAuth client is a public client, so this broker deliberately never
/// accepts or sends a client secret. Authorization-code exchanges are protected
/// by the PKCE verifier created by [DesktopGoogleOAuth].
class DirectDesktopGoogleTokenBroker implements DesktopGoogleTokenBroker {
  DirectDesktopGoogleTokenBroker({
    required String clientId,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _clientId = clientId.trim(),
       _httpClient = httpClient ?? http.Client();

  static final Uri _tokenEndpoint = Uri.https(
    'oauth2.googleapis.com',
    '/token',
  );

  final String _clientId;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<void> ensureReady() async {
    _requireClientId(operation: 'Direct Google OAuth preflight');
  }

  @override
  Future<DesktopGoogleTokenResponse> exchangeAuthorizationCode({
    required String authorizationCode,
    required String codeVerifier,
    required String redirectUri,
  }) {
    return _request(
      operation: 'Direct Google token exchange',
      form: {
        'client_id': _clientId,
        'code': authorizationCode,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
      sensitiveValues: [authorizationCode, codeVerifier],
    );
  }

  @override
  Future<DesktopGoogleTokenResponse> refresh({required String refreshToken}) {
    return _request(
      operation: 'Direct Google token refresh',
      form: {
        'client_id': _clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
      sensitiveValues: [refreshToken],
    );
  }

  Future<DesktopGoogleTokenResponse> _request({
    required String operation,
    required Map<String, String> form,
    required List<String> sensitiveValues,
  }) async {
    _requireClientId(operation: operation);
    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            _tokenEndpoint,
            headers: const {
              'content-type': 'application/x-www-form-urlencoded',
              'accept': 'application/json',
            },
            body: form,
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw GoogleOAuthException(
        operation: operation,
        statusCode: 504,
        code: 'google_oauth_timeout',
        description: 'Google OAuth token request timed out.',
      );
    } on Object {
      // Network exceptions may contain request details. Do not forward their
      // text because authorization codes, PKCE verifiers, and refresh tokens
      // must never enter diagnostics or logs.
      throw GoogleOAuthException(
        operation: operation,
        statusCode: 503,
        code: 'google_oauth_unreachable',
        description: 'Google OAuth token endpoint is temporarily unreachable.',
      );
    }

    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final googleError = _googleError(
        decoded,
        sensitiveValues: sensitiveValues,
      );
      throw GoogleOAuthException(
        operation: operation,
        statusCode: response.statusCode,
        code: googleError.code ?? 'google_oauth_http_error',
        description:
            googleError.description ??
            'Google OAuth token endpoint rejected the request.',
      );
    }

    final accessToken = decoded?['access_token'];
    final expiresIn = _positiveInteger(decoded?['expires_in']);
    final refreshToken = _optionalToken(decoded, 'refresh_token');
    final idToken = _optionalToken(decoded, 'id_token');
    if (accessToken is! String ||
        accessToken.isEmpty ||
        expiresIn == null ||
        refreshToken.invalid ||
        idToken.invalid) {
      throw GoogleOAuthException(
        operation: operation,
        statusCode: 502,
        code: 'google_oauth_invalid_response',
        description: 'Google returned an invalid OAuth token response.',
      );
    }
    return DesktopGoogleTokenResponse(
      accessToken: accessToken,
      refreshToken: refreshToken.value,
      idToken: idToken.value,
      expiresIn: expiresIn,
    );
  }

  void _requireClientId({required String operation}) {
    if (_clientId.isNotEmpty) return;
    throw GoogleOAuthException(
      operation: operation,
      statusCode: 400,
      code: 'google_client_id_missing',
      description: 'GOOGLE_DESKTOP_CLIENT_ID is not configured.',
    );
  }

  ({String? code, String? description}) _googleError(
    Map<String, Object?>? decoded, {
    required List<String> sensitiveValues,
  }) {
    final rawError = decoded?['error'];
    final nested = rawError is Map ? Map<String, Object?>.from(rawError) : null;
    final codeValue = rawError is String
        ? rawError
        : nested?['status'] ?? nested?['code'];
    final descriptionValue =
        decoded?['error_description'] ??
        decoded?['description'] ??
        decoded?['message'] ??
        nested?['error_description'] ??
        nested?['message'];
    return (
      code: _boundedText(codeValue),
      description: _boundedText(
        descriptionValue,
        sensitiveValues: sensitiveValues,
      ),
    );
  }

  String? _boundedText(Object? raw, {List<String> sensitiveValues = const []}) {
    if (raw == null) return null;
    var value = raw.toString().trim();
    if (value.isEmpty) return null;
    for (final sensitiveValue in sensitiveValues) {
      if (sensitiveValue.isNotEmpty) {
        value = value.replaceAll(sensitiveValue, '[REDACTED]');
      }
    }
    const maxLength = 500;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}…';
  }

  int? _positiveInteger(Object? value) {
    final parsed = switch (value) {
      final num number => number.toInt(),
      final String text => int.tryParse(text),
      _ => null,
    };
    return parsed != null && parsed > 0 ? parsed : null;
  }

  ({String? value, bool invalid}) _optionalToken(
    Map<String, Object?>? decoded,
    String key,
  ) {
    if (decoded == null || !decoded.containsKey(key) || decoded[key] == null) {
      return (value: null, invalid: false);
    }
    final value = decoded[key];
    return value is String && value.isNotEmpty
        ? (value: value, invalid: false)
        : (value: null, invalid: true);
  }

  Map<String, Object?>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      return null;
    }
  }
}
