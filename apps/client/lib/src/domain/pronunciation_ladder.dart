import 'learning_item.dart';

enum ShadowingStage {
  listen,
  slowListen,
  repeat,
  localRecording,
  hint,
  context,
}

extension ShadowingStageContent on ShadowingStage {
  String get label => switch (this) {
    ShadowingStage.listen => '듣기',
    ShadowingStage.slowListen => '느리게',
    ShadowingStage.repeat => '따라 읽기',
    ShadowingStage.localRecording => '녹음·내 음성',
    ShadowingStage.hint => '힌트 대화',
    ShadowingStage.context => '상황 연습',
  };

  String get instruction => switch (this) {
    ShadowingStage.listen => '먼저 목표 발음의 리듬을 들어 보세요.',
    ShadowingStage.slowListen => '0.75배속으로 음절과 단어 경계를 확인하세요.',
    ShadowingStage.repeat => '화면을 보며 같은 속도와 리듬으로 따라 읽으세요.',
    ShadowingStage.localRecording => '임시로 녹음한 내 목소리를 바로 다시 들어 보세요.',
    ShadowingStage.hint => '읽는 법과 뜻을 단서로 짧게 주고받아 보세요.',
    ShadowingStage.context => '예문이나 실제 상황을 떠올리며 표현을 완성하세요.',
  };
}

class PronunciationLadder {
  const PronunciationLadder._();

  static List<ShadowingStage> stagesFor(LearningItem item) => const [
    ShadowingStage.listen,
    ShadowingStage.slowListen,
    ShadowingStage.repeat,
    ShadowingStage.localRecording,
    ShadowingStage.hint,
    ShadowingStage.context,
  ];

  static String contextPrompt(LearningItem item) {
    final example = item.example?.trim();
    final translation = item.exampleTranslation?.trim();
    if (example != null && example.isNotEmpty) {
      return [
        '상황 문장: $example',
        if (translation != null && translation.isNotEmpty) '뜻: $translation',
        '목표 표현 “${item.text}”을 넣어 소리 내어 말해 보세요.',
      ].join('\n');
    }
    return '“${item.primaryTranslation}”이 필요한 상황을 떠올리고 '
        '“${item.text}”을 보지 않고 말해 보세요.';
  }
}
