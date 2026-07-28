enum PendingSyncEntityType { snapshot }

class PendingSyncOperation {
  const PendingSyncOperation({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAt,
    required this.createdAt,
  });

  final String operationId;
  final PendingSyncEntityType entityType;
  final String entityId;
  final Map<String, Object?> payload;
  final int attempts;
  final DateTime nextAttemptAt;
  final DateTime createdAt;

  bool isDue(DateTime now) => !nextAttemptAt.isAfter(now);

  PendingSyncOperation copyWith({
    Map<String, Object?>? payload,
    int? attempts,
    DateTime? nextAttemptAt,
  }) {
    return PendingSyncOperation(
      operationId: operationId,
      entityType: entityType,
      entityId: entityId,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt,
    );
  }
}

Duration pendingSyncBackoff(int attempts) {
  const seconds = [5, 10, 20, 40, 80, 160, 300];
  final index = (attempts - 1).clamp(0, seconds.length - 1);
  return Duration(seconds: seconds[index]);
}
