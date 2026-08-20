import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import 'package:sprache/src/services/temporary_voice_recording_service.dart';

void main() {
  test('voice practice uses lossless full-band mono without stacked DSP', () {
    expect(voicePracticeRecordConfig.encoder, AudioEncoder.wav);
    expect(voicePracticeRecordConfig.sampleRate, 48000);
    expect(voicePracticeRecordConfig.numChannels, 1);
    expect(voicePracticeRecordConfig.autoGain, isFalse);
    expect(voicePracticeRecordConfig.echoCancel, isFalse);
    expect(voicePracticeRecordConfig.noiseSuppress, isFalse);
  });

  test(
    'app-start janitor deletes only app-owned temporary voice files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sprache-voice-clean-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final abandoned = File(path.join(root.path, 'voice-abc-123.wav'));
      final abandonedM4a = File(path.join(root.path, 'voice-old.m4a'));
      final unrelated = File(path.join(root.path, 'notes.wav'));
      final nested = Directory(path.join(root.path, 'nested'));
      await abandoned.writeAsBytes([1, 2, 3]);
      await abandonedM4a.writeAsBytes([4, 5]);
      await unrelated.writeAsBytes([6]);
      await nested.create();
      final nestedVoice = File(path.join(nested.path, 'voice-nested.wav'));
      await nestedVoice.writeAsBytes([7]);

      final deleted = await TemporaryVoiceRecordingJanitor(
        root: () async => root.path,
      ).clearAbandonedFiles();

      expect(deleted, 2);
      expect(await abandoned.exists(), isFalse);
      expect(await abandonedM4a.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
      expect(await nestedVoice.exists(), isTrue);
    },
  );

  test('cleanup failure never blocks app startup', () async {
    final deleted = await TemporaryVoiceRecordingJanitor(
      root: () async => throw StateError('unavailable'),
    ).clearAbandonedFiles();

    expect(deleted, 0);
  });
}
