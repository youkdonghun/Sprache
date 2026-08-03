import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

class InboundFilePayload {
  const InboundFilePayload({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class PlatformInboundIntentSource {
  Future<String?> initialIntent();

  Stream<String> get intents;

  Future<InboundFilePayload> readFile(Uri uri);
}

final platformInboundIntentSourceProvider =
    Provider<PlatformInboundIntentSource>((ref) {
      final source = MethodChannelInboundIntentSource();
      ref.onDispose(source.dispose);
      return source;
    });

class MethodChannelInboundIntentSource implements PlatformInboundIntentSource {
  MethodChannelInboundIntentSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channelName = 'com.youkdonghun.sprache/inbound_intent';
  static const _maxInboundBytes = 32 * 1024 * 1024;

  final MethodChannel _channel;
  final StreamController<String> _intents = StreamController<String>.broadcast(
    sync: true,
  );

  @override
  Stream<String> get intents => _intents.stream;

  @override
  Future<String?> initialIntent() async {
    try {
      final value = await _channel.invokeMethod<String>(
        'getInitialInboundIntent',
      );
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<InboundFilePayload> readFile(Uri uri) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'readInboundFile',
        {'uri': uri.toString()},
      );
      final rawBytes = result?['bytes'];
      final bytes = switch (rawBytes) {
        Uint8List value => value,
        List<int> value => Uint8List.fromList(value),
        _ => null,
      };
      if (bytes == null) {
        throw const FormatException('운영체제에서 파일 내용을 전달하지 않았습니다.');
      }
      _validateSize(bytes.length);
      final name = (result?['name'] as String?)?.trim();
      return InboundFilePayload(
        name: name == null || name.isEmpty ? _fileName(uri) : name,
        bytes: bytes,
      );
    } on MissingPluginException {
      return _readLocalFile(uri);
    } on PlatformException catch (error) {
      if (uri.scheme == 'file') return _readLocalFile(uri);
      throw FormatException(error.message ?? '운영체제에서 파일을 안전하게 읽지 못했습니다.');
    }
  }

  Future<InboundFilePayload> _readLocalFile(Uri uri) async {
    if (uri.scheme != 'file') {
      throw const FormatException('이 기기에서 해당 파일 주소를 읽을 수 없습니다.');
    }
    final file = File(uri.toFilePath(windows: Platform.isWindows));
    final length = await file.length();
    _validateSize(length);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (chunk.length > _maxInboundBytes - builder.length) {
        throw const FormatException(
          'The file exceeds the safe import preview size.',
        );
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    _validateSize(bytes.length);
    return InboundFilePayload(name: _fileName(uri), bytes: bytes);
  }

  void _validateSize(int size) {
    if (size <= 0 || size > _maxInboundBytes) {
      throw const FormatException('파일이 비어 있거나 안전한 미리보기 크기를 초과했습니다.');
    }
  }

  String _fileName(Uri uri) {
    if (uri.pathSegments.isEmpty) return 'import.dat';
    return Uri.decodeComponent(uri.pathSegments.last);
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onInboundIntent') return null;
    final raw = call.arguments;
    if (raw is String && raw.trim().isNotEmpty && !_intents.isClosed) {
      _intents.add(raw.trim());
    }
    return null;
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _intents.close();
  }
}
