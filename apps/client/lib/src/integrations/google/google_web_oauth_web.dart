import 'dart:async';
import 'dart:js_interop';

import 'package:google_identity_services_web/oauth2.dart' as gis;

class WebGoogleAuthorization {
  const WebGoogleAuthorization({
    required this.accessToken,
    required this.expiresAt,
  });

  final String accessToken;
  final DateTime expiresAt;

  bool get isUsable =>
      expiresAt.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1)));
}

class GoogleWebOAuthClient {
  GoogleWebOAuthClient({required this.clientId});

  final String clientId;
  WebGoogleAuthorization? _authorization;

  static const scopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  WebGoogleAuthorization? get currentAuthorization =>
      _authorization?.isUsable == true ? _authorization : null;

  /// Reuses a previously approved Google browser session without displaying
  /// an account picker or consent screen. A missing/expired browser session is
  /// reported as `null`; only an explicit user reconnect may show UI.
  Future<WebGoogleAuthorization?> restoreAuthorization() async {
    final existing = currentAuthorization;
    if (existing != null) return existing;
    try {
      return await authorize();
    } catch (_) {
      return null;
    }
  }

  Future<WebGoogleAuthorization> authorize({
    bool forceAccountChoice = false,
  }) async {
    final existing = currentAuthorization;
    if (existing != null && !forceAccountChoice) return existing;

    final completer = Completer<WebGoogleAuthorization>();
    late final gis.TokenClient tokenClient;
    tokenClient = gis.oauth2.initTokenClient(
      gis.TokenClientConfig(
        client_id: clientId,
        scope: scopes,
        include_granted_scopes: true,
        prompt: forceAccountChoice ? 'select_account' : '',
        callback: (response) {
          final token = response.access_token;
          final error = response.error;
          if (error != null || token == null || token.isEmpty) {
            if (!completer.isCompleted) {
              completer.completeError(
                StateError(
                  response.error_description ??
                      error ??
                      'Google authorization did not return an access token.',
                ),
              );
            }
            return;
          }
          final lifetime = response.expires_in ?? 3600;
          final authorization = WebGoogleAuthorization(
            accessToken: token,
            expiresAt: DateTime.now().toUtc().add(Duration(seconds: lifetime)),
          );
          _authorization = authorization;
          if (!completer.isCompleted) completer.complete(authorization);
        },
        error_callback: (error) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError(error?.message ?? 'Google authorization was closed.'),
            );
          }
        },
      ),
    );
    // Always repeat the scopes in the request override. Some GIS SDK/browser
    // combinations treat an override object without `scope` as replacing the
    // initialization value, which makes Google reject the request with
    // "Missing required parameter scope".
    tokenClient.requestAccessToken(
      gis.OverridableTokenClientConfig(
        scope: scopes,
        include_granted_scopes: true,
        prompt: forceAccountChoice ? 'select_account' : '',
      ),
    );
    return completer.future;
  }

  Future<String?> pickDriveFolder({
    required String accessToken,
    required String apiKey,
  }) async {
    await _loadPicker();
    final completer = Completer<String?>();
    void onPickerResult(JSObject result) {
      final data = result.dartify();
      if (data is! Map) return;
      final action = data['action']?.toString();
      if (action == 'cancel') {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      if (action != 'picked') return;
      final documents = data['docs'];
      if (documents is! List || documents.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final first = documents.first;
      final id = first is Map ? first['id']?.toString().trim() : null;
      if (!completer.isCompleted) {
        completer.complete(id == null || id.isEmpty ? null : id);
      }
    }

    final view = _PickerDocsView(_pickerFoldersViewId)
      ..setIncludeFolders(true)
      ..setSelectFolderEnabled(true);
    final picker = _PickerBuilder()
        .addView(view)
        .setOAuthToken(accessToken)
        .setDeveloperKey(apiKey)
        .setCallback(onPickerResult.toJS)
        .build();
    picker.setVisible(true);
    return completer.future;
  }

  Future<void> disconnect() async {
    final token = _authorization?.accessToken;
    _authorization = null;
    if (token == null || token.isEmpty) return;
    final completer = Completer<void>();
    gis.oauth2.revoke(token, (_) => completer.complete());
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  Future<void> _loadPicker() async {
    final completer = Completer<void>();
    _gapiLoad('picker'.toJS, (() => completer.complete()).toJS);
    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Google Picker did not load.'),
    );
  }
}

@JS('gapi.load')
external void _gapiLoad(JSString library, JSFunction callback);

@JS('google.picker.ViewId.FOLDERS')
external JSAny get _pickerFoldersViewId;

@JS('google.picker.DocsView')
extension type _PickerDocsView._(JSObject _) implements JSObject {
  external factory _PickerDocsView([JSAny viewId]);
  external _PickerDocsView setIncludeFolders(bool value);
  external _PickerDocsView setSelectFolderEnabled(bool value);
}

@JS('google.picker.PickerBuilder')
extension type _PickerBuilder._(JSObject _) implements JSObject {
  external factory _PickerBuilder();
  external _PickerBuilder addView(_PickerDocsView view);
  external _PickerBuilder setOAuthToken(String token);
  external _PickerBuilder setDeveloperKey(String apiKey);
  external _PickerBuilder setCallback(JSFunction callback);
  external _Picker build();
}

extension type _Picker._(JSObject _) implements JSObject {
  external void setVisible(bool visible);
}
