import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: target,
    );
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
