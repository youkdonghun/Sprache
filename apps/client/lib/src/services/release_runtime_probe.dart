import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef ReleaseProbeDirectoryResolver = Future<Directory> Function();
typedef ReleaseProbeClock = DateTime Function();
typedef ReleaseProbeFrameCapture = Future<Uint8List> Function();

class ReleaseRuntimeProbe {
  ReleaseRuntimeProbe({
    required this.enabled,
    required this.platform,
    required this.mode,
    required this.version,
    required this.buildNumber,
    required this.probe,
    ReleaseProbeDirectoryResolver? directoryResolver,
    ReleaseProbeClock? clock,
    Stopwatch? startupStopwatch,
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now,
       _startupStopwatch = startupStopwatch ?? (Stopwatch()..start());

  factory ReleaseRuntimeProbe.fromEnvironment(TargetPlatform platform) {
    const compileTimeEnabled = bool.fromEnvironment(
      'ENABLE_RELEASE_PROBE',
      defaultValue: false,
    );
    final runtimeEnabled =
        Platform.environment['SPRACHE_ENABLE_RELEASE_PROBE']?.trim() == '1';
    const mode = String.fromEnvironment(
      'RELEASE_PROBE_MODE',
      defaultValue: 'MOCK',
    );
    const version = String.fromEnvironment('APP_VERSION');
    const buildNumberText = String.fromEnvironment('RELEASE_BUILD_NUMBER');
    const probe = String.fromEnvironment(
      'RELEASE_PROBE_KIND',
      defaultValue: 'flutter-first-frame',
    );
    final outputDirectory =
        Platform.environment['SPRACHE_RELEASE_PROBE_DIRECTORY']?.trim();
    return ReleaseRuntimeProbe(
      enabled: compileTimeEnabled || runtimeEnabled,
      platform: _platformName(platform),
      mode: mode,
      version: version,
      buildNumber: int.tryParse(buildNumberText) ?? 0,
      probe: probe,
      directoryResolver: outputDirectory == null || outputDirectory.isEmpty
          ? null
          : () async => Directory(outputDirectory),
    );
  }

  static const evidenceFileName = 'sprache-runtime-evidence-v1.json';
  static const frameFileName = 'sprache-runtime-frame-v1.png';
  static const _allowedModes = {'REAL', 'MOCK'};
  static const _allowedProbes = {
    'native-runtime',
    'simulator-runtime',
    'flutter-first-frame',
  };

  final bool enabled;
  final String platform;
  final String mode;
  final String version;
  final int buildNumber;
  final String probe;
  final ReleaseProbeDirectoryResolver _directoryResolver;
  final ReleaseProbeClock _clock;
  final Stopwatch _startupStopwatch;

  Future<File?> recordAfterFirstFrame(
    Future<void> endOfFrame, {
    ReleaseProbeFrameCapture? captureFrame,
  }) async {
    if (!enabled) return null;
    _validateConfiguration();
    if (captureFrame == null) {
      throw StateError('Enabled release probes require a frame capture.');
    }
    await endOfFrame;

    final frameBytes = await captureFrame();
    _validatePng(frameBytes);
    final frameSha256 = sha256.convert(frameBytes).toString();

    final directory = await _directoryResolver();
    await directory.create(recursive: true);
    final evidenceFile = File(path.join(directory.path, evidenceFileName));
    final frameFile = File(path.join(directory.path, frameFileName));
    final recordedAt = _clock();
    final transactionId = recordedAt.microsecondsSinceEpoch;
    final temporaryEvidenceFile = File(
      '${evidenceFile.path}.tmp-$transactionId',
    );
    final temporaryFrameFile = File('${frameFile.path}.tmp-$transactionId');
    final evidenceBackupFile = File(
      '${evidenceFile.path}.backup-$transactionId',
    );
    final frameBackupFile = File('${frameFile.path}.backup-$transactionId');
    final evidence = <String, Object>{
      'format': 'sprache-runtime-evidence-v1',
      'platform': platform,
      'mode': mode,
      'version': version,
      'buildNumber': buildNumber,
      'launched': true,
      'firstFrameRendered': true,
      'firstFrameMillis': _startupStopwatch.elapsedMilliseconds,
      'probe': probe,
      'frameFile': frameFileName,
      'frameSha256': frameSha256,
      'checkedAt': recordedAt.toUtc().toIso8601String(),
    };

    var evidenceBackedUp = false;
    var frameBackedUp = false;
    var evidencePublished = false;
    var framePublished = false;
    var committed = false;
    try {
      await temporaryFrameFile.writeAsBytes(frameBytes, flush: true);
      await temporaryEvidenceFile.writeAsString(
        '${jsonEncode(evidence)}\n',
        encoding: utf8,
        flush: true,
      );

      // The JSON is the commit marker. Hide the previous marker first and
      // publish the new marker last so readers never accept a mismatched pair.
      if (await evidenceFile.exists()) {
        await evidenceFile.rename(evidenceBackupFile.path);
        evidenceBackedUp = true;
      }
      if (await frameFile.exists()) {
        await frameFile.rename(frameBackupFile.path);
        frameBackedUp = true;
      }
      await temporaryFrameFile.rename(frameFile.path);
      framePublished = true;
      await temporaryEvidenceFile.rename(evidenceFile.path);
      evidencePublished = true;
      committed = true;
      return evidenceFile;
    } catch (_) {
      if (evidencePublished && await evidenceFile.exists()) {
        await evidenceFile.delete();
      }
      if (framePublished && await frameFile.exists()) {
        await frameFile.delete();
      }
      if (frameBackedUp && await frameBackupFile.exists()) {
        await frameBackupFile.rename(frameFile.path);
      }
      if (evidenceBackedUp && await evidenceBackupFile.exists()) {
        await evidenceBackupFile.rename(evidenceFile.path);
      }
      rethrow;
    } finally {
      await _deleteIfExists(temporaryEvidenceFile);
      await _deleteIfExists(temporaryFrameFile);
      if (committed) {
        await _deleteIfExists(evidenceBackupFile);
        await _deleteIfExists(frameBackupFile);
      }
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  static void _validatePng(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length) {
      throw StateError('Release frame capture is not a PNG image.');
    }
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) {
        throw StateError('Release frame capture is not a PNG image.');
      }
    }
  }

  void _validateConfiguration() {
    if (!_allowedModes.contains(mode)) {
      throw StateError('Unsupported release probe mode: $mode');
    }
    if (!_allowedProbes.contains(probe)) {
      throw StateError('Unsupported release probe kind: $probe');
    }
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw StateError('Release probe version must use x.y.z: $version');
    }
    if (buildNumber <= 0) {
      throw StateError('Release probe build number must be positive.');
    }
  }

  static String _platformName(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
