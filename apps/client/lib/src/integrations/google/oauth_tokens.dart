import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum GoogleTokenKind { identity, drive }

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
    this.idToken,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime expiresAt;

  bool get isAccessTokenUsable =>
      expiresAt.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1)));

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory OAuthTokens.fromJson(Map<String, Object?> json) => OAuthTokens(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken'] as String?,
    idToken: json['idToken'] as String?,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
  );
}

abstract interface class TokenVault {
  Future<OAuthTokens?> read(GoogleTokenKind kind);

  Future<void> write(GoogleTokenKind kind, OAuthTokens tokens);

  Future<void> clear();
}

class SecureTokenVault implements TokenVault {
  SecureTokenVault() : _storage = const FlutterSecureStorage();

  SecureTokenVault.withStorage(this._storage);

  final FlutterSecureStorage _storage;

  String _key(GoogleTokenKind kind) => 'google_oauth_${kind.name}';

  @override
  Future<OAuthTokens?> read(GoogleTokenKind kind) async {
    final value = await _storage.read(key: _key(kind));
    if (value == null) return null;
    return OAuthTokens.fromJson(jsonDecode(value) as Map<String, Object?>);
  }

  @override
  Future<void> write(GoogleTokenKind kind, OAuthTokens tokens) {
    return _storage.write(key: _key(kind), value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() async {
    for (final kind in GoogleTokenKind.values) {
      await _storage.delete(key: _key(kind));
    }
  }
}

class MemoryTokenVault implements TokenVault {
  final _tokens = <GoogleTokenKind, OAuthTokens>{};

  @override
  Future<OAuthTokens?> read(GoogleTokenKind kind) async => _tokens[kind];

  @override
  Future<void> write(GoogleTokenKind kind, OAuthTokens tokens) async {
    _tokens[kind] = tokens;
  }

  @override
  Future<void> clear() async => _tokens.clear();
}
