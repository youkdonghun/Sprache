import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/learning_item.dart';
import '../domain/session_enhancements.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../state/app_state.dart';

Future<void> handleQuickContentResult({
  required BuildContext context,
  required WidgetRef ref,
  required QuickContentSaveResult? result,
}) async {
  if (result == null || !context.mounted) return;
  final mergedMessage = result.addedMeaningCount > 0
      ? '기존 표현에 새 뜻 ${result.addedMeaningCount}개를 추가했어요.'
      : '같은 표현과 뜻이 이미 있어 한 번만 저장했어요.';
  final message = result.mergedWithExisting
      ? mergedMessage
      : '“${result.item.text}”을 저장했어요.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: '실행 취소',
        onPressed: () => unawaited(
          _undoQuickContent(context: context, ref: ref, result: result),
        ),
      ),
    ),
  );

  if (!result.studyNow || !context.mounted) return;
  final controller = ref.read(appControllerProvider.notifier);
  controller.updateSessionPlan(
    controller.activeSessionPlan.copyWith(
      planId: '',
      title: '방금 저장한 자료 학습',
      mode: StudyMode.mixed,
      deck: StudyDeckScope.selected,
      difficulty: StudyDifficulty.all,
      groupIds: {},
      tags: {},
      levels: {},
      selectedItemIds: {result.item.id},
      includeWords: result.item.kind == LearningItemKind.word,
      includeSentences: result.item.kind == LearningItemKind.sentence,
      itemLimit: StudyLimits.minSessionItems,
      lengthMode: StudySessionLengthMode.itemCount,
      recordProgress: true,
      scheduledAt: null,
    ),
  );
  context.push('/session-builder');
}

Future<void> _undoQuickContent({
  required BuildContext context,
  required WidgetRef ref,
  required QuickContentSaveResult result,
}) async {
  final controller = ref.read(appControllerProvider.notifier);
  final status = await controller.undoQuickContentSave(result.undoToken);
  if (!context.mounted) return;
  if (status == QuickContentUndoStatus.restored &&
      result.favoriteAdded &&
      ref.read(appControllerProvider).preferences.isFavorite(result.item.id)) {
    controller.toggleFavorite(result.item.id);
  }
  final message = switch (status) {
    QuickContentUndoStatus.restored => '마지막 저장을 되돌렸어요.',
    QuickContentUndoStatus.conflict => '저장한 뒤 수정된 자료라 자동으로 되돌리지 않았어요.',
    QuickContentUndoStatus.alreadyUndone => '이미 되돌린 내용이에요.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
