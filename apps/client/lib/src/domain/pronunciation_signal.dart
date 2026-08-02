enum PronunciationSignalIssue { none, noInput, backgroundNoise, wrongLocale }

class PronunciationSignalAssessment {
  const PronunciationSignalAssessment({
    required this.issue,
    required this.message,
    required this.canScore,
  });

  final PronunciationSignalIssue issue;
  final String message;
  final bool canScore;
}

class PronunciationSignalInspector {
  const PronunciationSignalInspector();

  PronunciationSignalAssessment inspect({
    required String transcript,
    required Iterable<double> soundLevels,
    required String requestedLocale,
    Iterable<String>? availableLocales,
  }) {
    final safeLevels = soundLevels.where((value) => value.isFinite).take(500);
    final values = safeLevels.toList(growable: false);
    final hasLocale =
        availableLocales == null ||
        availableLocales.any(
          (locale) => _language(locale) == _language(requestedLocale),
        );
    if (!hasLocale) {
      return const PronunciationSignalAssessment(
        issue: PronunciationSignalIssue.wrongLocale,
        message: '목표 언어 음성팩이 없어 자동 채점 대신 자기 평가를 사용해 주세요.',
        canScore: false,
      );
    }
    final normalized = transcript.trim();
    if (normalized.isEmpty) {
      return const PronunciationSignalAssessment(
        issue: PronunciationSignalIssue.noInput,
        message: '목소리 입력이 확인되지 않았어요. 마이크 가까이에서 다시 말해 보세요.',
        canScore: false,
      );
    }
    if (values.length >= 4) {
      final average =
          values.reduce((left, right) => left + right) / values.length;
      final peak = values.reduce((left, right) => left > right ? left : right);
      if (average > 7 && peak - average < 2.5 && normalized.length < 4) {
        return const PronunciationSignalAssessment(
          issue: PronunciationSignalIssue.backgroundNoise,
          message: '배경 소음이 큰 것 같아요. 조용한 곳에서 다시 시도하거나 자기 평가를 사용해 주세요.',
          canScore: false,
        );
      }
    }
    return const PronunciationSignalAssessment(
      issue: PronunciationSignalIssue.none,
      message: '음성 입력 상태가 양호해요.',
      canScore: true,
    );
  }

  String _language(String locale) =>
      locale.trim().toLowerCase().split(RegExp('[-_]')).first;
}
