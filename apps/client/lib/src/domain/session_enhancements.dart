import 'study_limits.dart';

enum StudySessionLengthMode { itemCount, timeBudget }

enum StudyGradingStrictness { lenient, balanced, strict }

class ExamSchedule {
  const ExamSchedule({
    required this.targetDate,
    this.startDate,
    this.dailyCap = 30,
    this.preferredMinuteOfDay = 19 * 60,
    this.lastCompletedAt,
    this.snoozedUntil,
    this.updatedAt,
  });

  final DateTime targetDate;
  final DateTime? startDate;
  final int dailyCap;
  final int preferredMinuteOfDay;
  final DateTime? lastCompletedAt;
  final DateTime? snoozedUntil;
  final DateTime? updatedAt;

  int recommendedDailyItems({
    required int remainingItems,
    required DateTime now,
  }) {
    if (remainingItems <= 0) return 0;
    final today = DateTime.utc(now.year, now.month, now.day);
    final target = DateTime.utc(
      targetDate.toUtc().year,
      targetDate.toUtc().month,
      targetDate.toUtc().day,
    );
    final days = target.difference(today).inDays.clamp(0, 3650) + 1;
    return ((remainingItems / days).ceil()).clamp(1, dailyCap.clamp(1, 100));
  }

  bool isCompletedOn(DateTime value) {
    final completed = lastCompletedAt?.toLocal();
    final local = value.toLocal();
    return completed != null &&
        completed.year == local.year &&
        completed.month == local.month &&
        completed.day == local.day;
  }

  DateTime nextStudyAt(DateTime now, {bool tomorrow = false}) {
    final localNow = now.toLocal();
    final minute = preferredMinuteOfDay.clamp(0, 1439);
    var day = DateTime(localNow.year, localNow.month, localNow.day);
    if (tomorrow) day = day.add(const Duration(days: 1));
    var candidate = DateTime(
      day.year,
      day.month,
      day.day,
      minute ~/ 60,
      minute % 60,
    );
    if (!tomorrow && !candidate.isAfter(localNow)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate.toUtc();
  }

  ExamSchedule copyWith({
    DateTime? targetDate,
    Object? startDate = _notProvided,
    int? dailyCap,
    int? preferredMinuteOfDay,
    Object? lastCompletedAt = _notProvided,
    Object? snoozedUntil = _notProvided,
    Object? updatedAt = _notProvided,
  }) {
    return ExamSchedule(
      targetDate: targetDate ?? this.targetDate,
      startDate: identical(startDate, _notProvided)
          ? this.startDate
          : startDate as DateTime?,
      dailyCap: dailyCap ?? this.dailyCap,
      preferredMinuteOfDay: preferredMinuteOfDay ?? this.preferredMinuteOfDay,
      lastCompletedAt: identical(lastCompletedAt, _notProvided)
          ? this.lastCompletedAt
          : lastCompletedAt as DateTime?,
      snoozedUntil: identical(snoozedUntil, _notProvided)
          ? this.snoozedUntil
          : snoozedUntil as DateTime?,
      updatedAt: identical(updatedAt, _notProvided)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'targetDate': targetDate.toUtc().toIso8601String(),
    if (startDate != null) 'startDate': startDate!.toUtc().toIso8601String(),
    'dailyCap': dailyCap.clamp(1, 100),
    'preferredMinuteOfDay': preferredMinuteOfDay.clamp(0, 1439),
    if (lastCompletedAt != null)
      'lastCompletedAt': lastCompletedAt!.toUtc().toIso8601String(),
    if (snoozedUntil != null)
      'snoozedUntil': snoozedUntil!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  factory ExamSchedule.fromJson(Map<String, Object?> json) {
    final targetDate = DateTime.tryParse(json['targetDate'] as String? ?? '');
    if (targetDate == null) {
      throw const FormatException('시험 목표일이 올바르지 않습니다.');
    }
    return ExamSchedule(
      targetDate: targetDate.toUtc(),
      startDate: switch (json['startDate']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      dailyCap: ((json['dailyCap'] as num?)?.toInt() ?? 30).clamp(1, 100),
      preferredMinuteOfDay:
          ((json['preferredMinuteOfDay'] as num?)?.toInt() ?? 19 * 60).clamp(
            0,
            1439,
          ),
      lastCompletedAt: switch (json['lastCompletedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      snoozedUntil: switch (json['snoozedUntil']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }
}

class BacklogRecoverySettings {
  const BacklogRecoverySettings({this.enabled = false, this.dailyLimit = 30});

  final bool enabled;
  final int dailyLimit;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'dailyLimit': dailyLimit.clamp(1, StudyLimits.maxSessionItems),
  };

  factory BacklogRecoverySettings.fromJson(Map<String, Object?> json) {
    return BacklogRecoverySettings(
      enabled: json['enabled'] == true,
      dailyLimit: ((json['dailyLimit'] as num?)?.toInt() ?? 30).clamp(
        1,
        StudyLimits.maxSessionItems,
      ),
    );
  }
}

const _notProvided = Object();
