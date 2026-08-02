import '../domain/learning_insights.dart';

class StudySummaryExporter {
  const StudySummaryExporter();

  String exportCsv(LearningInsights insights) {
    final rows = <List<Object?>>[
      const [
        'date',
        'sessions',
        'minutes',
        'xp',
        'correct',
        'wrong',
        'attempts',
        'accuracy_percent',
      ],
      for (final day in insights.days)
        [
          _date(day.date),
          day.sessionCount,
          day.duration.inSeconds / 60,
          day.earnedXp,
          day.correctCount,
          day.wrongCount,
          day.attempts,
          day.accuracy == null ? '' : (day.accuracy! * 100).toStringAsFixed(1),
        ],
    ];
    return '${rows.map(_row).join('\r\n')}\r\n';
  }

  String _row(List<Object?> values) => values.map(_cell).join(',');

  String _cell(Object? value) {
    final text = value is double
        ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
        : '$value';
    if (!text.contains(RegExp('[,"\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
