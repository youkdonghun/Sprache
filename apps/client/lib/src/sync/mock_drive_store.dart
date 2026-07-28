import 'dart:convert';

class DriveObject {
  const DriveObject({
    required this.content,
    required this.revision,
    required this.updatedAt,
  });

  final List<int> content;
  final int revision;
  final DateTime updatedAt;
}

abstract interface class DriveStore {
  Future<DriveObject?> read(String key);

  Future<DriveObject> write(
    String key,
    List<int> content, {
    int? expectedRevision,
  });
}

class DriveRevisionConflict implements Exception {
  const DriveRevisionConflict(this.key);

  final String key;

  @override
  String toString() => 'Drive revision conflict for $key';
}

class MockDriveStore implements DriveStore {
  final _objects = <String, DriveObject>{};
  bool failNetwork = false;

  @override
  Future<DriveObject?> read(String key) async {
    _checkNetwork();
    return _objects[key];
  }

  @override
  Future<DriveObject> write(
    String key,
    List<int> content, {
    int? expectedRevision,
  }) async {
    _checkNetwork();
    final current = _objects[key];
    if (expectedRevision != null && current?.revision != expectedRevision) {
      throw DriveRevisionConflict(key);
    }
    final next = DriveObject(
      content: List<int>.unmodifiable(content),
      revision: (current?.revision ?? 0) + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    _objects[key] = next;
    return next;
  }

  Future<DriveObject> writeJson(
    String key,
    Map<String, Object?> value, {
    int? expectedRevision,
  }) {
    return write(
      key,
      utf8.encode(jsonEncode(value)),
      expectedRevision: expectedRevision,
    );
  }

  void _checkNetwork() {
    if (failNetwork) {
      throw const SocketLikeNetworkException();
    }
  }
}

class SocketLikeNetworkException implements Exception {
  const SocketLikeNetworkException();

  @override
  String toString() => 'Mock network is unavailable';
}
