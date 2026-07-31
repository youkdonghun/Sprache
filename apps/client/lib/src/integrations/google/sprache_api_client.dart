import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class DriveRootBinding {
  const DriveRootBinding({
    required this.folderId,
    required this.folderName,
    required this.schemaVersion,
  });

  final String folderId;
  final String? folderName;
  final int schemaVersion;
}

class SpracheApiClient {
  SpracheApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  Future<bool> verify(String idToken) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/v1/auth/verify'),
          headers: {'authorization': 'Bearer $idToken'},
        )
        .timeout(requestTimeout);
    _ensureSuccess(response, operation: 'verify account');
    final body = jsonDecode(response.body) as Map<String, Object?>;
    return body['driveConnected']! as bool;
  }

  Future<DriveRootBinding?> getDriveRoot({required String idToken}) async {
    final response = await _httpClient
        .get(
          Uri.parse('$baseUrl/v1/me/drive-root'),
          headers: {'authorization': 'Bearer $idToken'},
        )
        .timeout(requestTimeout);
    _ensureSuccess(response, operation: 'read Drive root');
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final rawBinding = body['binding'];
    if (rawBinding == null) return null;
    final binding = Map<String, Object?>.from(rawBinding as Map);
    return DriveRootBinding(
      folderId: binding['folderId']! as String,
      folderName: binding['folderName'] as String?,
      schemaVersion: binding['schemaVersion']! as int,
    );
  }

  Future<void> storeDriveRoot({
    required String idToken,
    required String folderId,
    required String folderName,
    int schemaVersion = 1,
  }) async {
    final response = await _httpClient
        .put(
          Uri.parse('$baseUrl/v1/me/drive-root'),
          headers: {
            'authorization': 'Bearer $idToken',
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'folderId': folderId,
            'folderName': folderName,
            'schemaVersion': schemaVersion,
          }),
        )
        .timeout(requestTimeout);
    _ensureSuccess(response, operation: 'store Drive root');
  }

  Future<void> deleteDriveRoot({required String idToken}) async {
    final response = await _httpClient
        .delete(
          Uri.parse('$baseUrl/v1/me/drive-root'),
          headers: {'authorization': 'Bearer $idToken'},
        )
        .timeout(requestTimeout);
    _ensureSuccess(response, operation: 'delete Drive root');
  }

  void _ensureSuccess(http.Response response, {required String operation}) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$operation failed (${response.statusCode})');
    }
  }
}
