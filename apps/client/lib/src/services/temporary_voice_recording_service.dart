import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

abstract interface class TemporaryVoiceRecordingService {
  bool get isRecording;
  bool get hasRecording;

  Future<bool> start();

  Future<bool> stop();

  Future<void> play();

  Future<void> clear();

  Future<void> dispose();
}

typedef TemporaryVoiceRootResolver = Future<String> Function();

/// Lossless full-band speech without stacking device audio processors.
///
/// The old 16 kHz profile enabled automatic gain, echo cancellation and noise
/// suppression together. On devices that already process microphone input,
/// that combination can pump the level and clip consonants.
const voicePracticeRecordConfig = RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 48000,
  numChannels: 1,
  autoGain: false,
  echoCancel: false,
  noiseSuppress: false,
);

class TemporaryVoiceRecordingJanitor {
  const TemporaryVoiceRecordingJanitor({TemporaryVoiceRootResolver? root})
    : _root = root ?? _defaultRoot;

  final TemporaryVoiceRootResolver _root;

  Future<int> clearAbandonedFiles() async {
    late final Directory directory;
    try {
      directory = Directory(await _root());
    } on Object {
      return 0;
    }
    if (!await directory.exists()) return 0;
    var deleted = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = path.basename(entity.path).toLowerCase();
      if (!RegExp(r'^voice-[a-z0-9-]+\.(wav|m4a|aac)$').hasMatch(name)) {
        continue;
      }
      try {
        await entity.delete();
        deleted += 1;
      } on FileSystemException {
        // A locked or already removed file is retried on the next app start.
      }
    }
    return deleted;
  }

  static Future<String> _defaultRoot() async {
    final directory = await getTemporaryDirectory();
    return path.join(directory.path, 'sprache', 'voice-practice');
  }
}

class DeviceTemporaryVoiceRecordingService
    implements TemporaryVoiceRecordingService {
  DeviceTemporaryVoiceRecordingService({
    AudioRecorder? recorder,
    AudioPlayer? player,
  }) : _recorder = recorder ?? AudioRecorder(),
       _player = player ?? AudioPlayer();

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  String? _recordingPath;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get hasRecording => _recordingPath != null;

  @override
  Future<bool> start() async {
    await clear();
    if (!await _recorder.hasPermission()) return false;
    final directory = await getTemporaryDirectory();
    final voiceDirectory = Directory(
      path.join(directory.path, 'sprache', 'voice-practice'),
    );
    await voiceDirectory.create(recursive: true);
    final target = path.join(
      voiceDirectory.path,
      'voice-${const Uuid().v4()}.wav',
    );
    await _recorder.start(voicePracticeRecordConfig, path: target);
    _recordingPath = target;
    _isRecording = true;
    return true;
  }

  @override
  Future<bool> stop() async {
    if (!_isRecording) return hasRecording;
    final recordedPath = await _recorder.stop();
    _isRecording = false;
    if (recordedPath == null || recordedPath.trim().isEmpty) {
      await clear();
      return false;
    }
    _recordingPath = recordedPath;
    return File(recordedPath).exists();
  }

  @override
  Future<void> play() async {
    final recordedPath = _recordingPath;
    if (recordedPath == null || !await File(recordedPath).exists()) {
      throw const FileSystemException('임시 발음 녹음 파일을 찾을 수 없습니다.');
    }
    await _player.stop();
    final completed = _player.onPlayerComplete.first;
    await _player.play(DeviceFileSource(recordedPath));
    await completed.timeout(const Duration(minutes: 2));
  }

  @override
  Future<void> clear() async {
    await _player.stop();
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
    final recordedPath = _recordingPath;
    _recordingPath = null;
    if (recordedPath == null) return;
    final file = File(recordedPath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> dispose() async {
    await clear();
    await _recorder.dispose();
    await _player.dispose();
  }
}
