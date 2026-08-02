import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sprache/src/services/release_runtime_probe.dart';

void main() {
  final framePng = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  test('disabled probe neither waits for a frame nor writes a file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-release-probe-disabled-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final neverCompletes = Completer<void>();
    final probe = ReleaseRuntimeProbe(
      enabled: false,
      platform: 'windows',
      mode: 'REAL',
      version: '1.31.0',
      buildNumber: 55,
      probe: 'native-runtime',
      directoryResolver: () async => directory,
    );

    expect(await probe.recordAfterFirstFrame(neverCompletes.future), isNull);
    expect(directory.listSync(), isEmpty);
  });

  test('enabled probe writes evidence only after the first frame', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-release-probe-enabled-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final firstFrame = Completer<void>();
    final checkedAt = DateTime.utc(2026, 8, 3, 6, 30);
    final probe = ReleaseRuntimeProbe(
      enabled: true,
      platform: 'ios',
      mode: 'MOCK',
      version: '1.31.0',
      buildNumber: 55,
      probe: 'simulator-runtime',
      directoryResolver: () async => directory,
      clock: () => checkedAt,
      startupStopwatch: Stopwatch(),
    );

    final write = probe.recordAfterFirstFrame(
      firstFrame.future,
      captureFrame: () async => framePng,
    );
    await Future<void>.delayed(Duration.zero);
    final expected = File(
      path.join(directory.path, ReleaseRuntimeProbe.evidenceFileName),
    );
    expect(expected.existsSync(), isFalse);
    final expectedFrame = File(
      path.join(directory.path, ReleaseRuntimeProbe.frameFileName),
    );
    expect(expectedFrame.existsSync(), isFalse);

    firstFrame.complete();
    final file = await write;
    expect(file?.path, expected.path);
    final json =
        jsonDecode(await expected.readAsString()) as Map<String, dynamic>;
    expect(json, {
      'format': 'sprache-runtime-evidence-v1',
      'platform': 'ios',
      'mode': 'MOCK',
      'version': '1.31.0',
      'buildNumber': 55,
      'launched': true,
      'firstFrameRendered': true,
      'firstFrameMillis': 0,
      'probe': 'simulator-runtime',
      'frameFile': ReleaseRuntimeProbe.frameFileName,
      'frameSha256': sha256.convert(framePng).toString(),
      'checkedAt': checkedAt.toIso8601String(),
    });
    expect(await expectedFrame.readAsBytes(), framePng);
    expect(
      directory.listSync().map((entry) => path.basename(entry.path)),
      unorderedEquals([
        ReleaseRuntimeProbe.evidenceFileName,
        ReleaseRuntimeProbe.frameFileName,
      ]),
    );
  });

  test(
    'invalid enabled configuration is rejected before evidence is written',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sprache-release-probe-invalid-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final probe = ReleaseRuntimeProbe(
        enabled: true,
        platform: 'macos',
        mode: 'PRETEND',
        version: 'development',
        buildNumber: 0,
        probe: 'native-runtime',
        directoryResolver: () async => directory,
      );

      await expectLater(
        probe.recordAfterFirstFrame(Future<void>.value()),
        throwsA(isA<StateError>()),
      );
      expect(directory.listSync(), isEmpty);
    },
  );

  test(
    'enabled probe rejects a missing frame capture without writing',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sprache-release-probe-missing-frame-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final probe = ReleaseRuntimeProbe(
        enabled: true,
        platform: 'windows',
        mode: 'REAL',
        version: '1.31.0',
        buildNumber: 55,
        probe: 'native-runtime',
        directoryResolver: () async => directory,
      );

      await expectLater(
        probe.recordAfterFirstFrame(Future<void>.value()),
        throwsA(isA<StateError>()),
      );
      expect(directory.listSync(), isEmpty);
    },
  );

  test('enabled probe rejects non-PNG frame bytes without writing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sprache-release-probe-invalid-frame-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final probe = ReleaseRuntimeProbe(
      enabled: true,
      platform: 'windows',
      mode: 'REAL',
      version: '1.31.0',
      buildNumber: 55,
      probe: 'native-runtime',
      directoryResolver: () async => directory,
    );

    await expectLater(
      probe.recordAfterFirstFrame(
        Future<void>.value(),
        captureFrame: () async => Uint8List.fromList(utf8.encode('not-png')),
      ),
      throwsA(isA<StateError>()),
    );
    expect(directory.listSync(), isEmpty);
  });
}
