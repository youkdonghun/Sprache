import 'package:flutter/material.dart';

enum LearningDataStep { add, organize, learn }

class LearningDataFlowCard extends StatelessWidget {
  const LearningDataFlowCard({
    required this.totalCount,
    required this.localCopyCount,
    required this.groupCount,
    required this.driveConnected,
    this.currentStep,
    this.onAdd,
    this.onOrganize,
    this.onLearn,
    this.syncLabel,
    this.syncBusy = false,
    this.onSync,
    this.localFolderConfigured = false,
    this.localFolderName,
    this.onManageStorage,
    this.condensed = false,
    super.key,
  });

  final int totalCount;
  final int localCopyCount;
  final int groupCount;
  final bool driveConnected;
  final LearningDataStep? currentStep;
  final VoidCallback? onAdd;
  final VoidCallback? onOrganize;
  final VoidCallback? onLearn;
  final String? syncLabel;
  final bool syncBusy;
  final VoidCallback? onSync;
  final bool localFolderConfigured;
  final String? localFolderName;
  final VoidCallback? onManageStorage;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (condensed) {
      final primaryAction = switch (currentStep) {
        LearningDataStep.add => onAdd,
        LearningDataStep.organize => onOrganize,
        LearningDataStep.learn => onLearn,
        null => null,
      };
      final primaryIcon = switch (currentStep) {
        LearningDataStep.add => Icons.add_rounded,
        LearningDataStep.organize => Icons.folder_copy_outlined,
        LearningDataStep.learn => Icons.school_outlined,
        null => Icons.arrow_forward_rounded,
      };
      return Material(
        key: const Key('learning-data-flow-card'),
        color: colors.secondaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: () => _showStorageDetails(context),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 22,
                    color: colors.onSecondaryContainer,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _compactFlowLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _storageSummaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (primaryAction != null)
                    IconButton(
                      key: const Key('learning-data-flow-primary'),
                      onPressed: primaryAction,
                      icon: Icon(primaryIcon),
                      tooltip: _recommendedTitle,
                    ),
                  IconButton(
                    key: const Key('open-learning-data-details-condensed'),
                    onPressed: () => _showStorageDetails(context),
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: '저장 위치 자세히 보기',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      key: const Key('learning-data-flow-card'),
      color: colors.secondaryContainer.withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showStorageDetails(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final title = Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        Icons.account_tree_outlined,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recommendedTitle,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _storageSummaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 340) {
                return Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: SizedBox.square(
                        dimension: 38,
                        child: Icon(
                          Icons.account_tree_outlined,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _compactFlowLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _storageSummaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('open-learning-data-details-very-compact'),
                      onPressed: () => _showStorageDetails(context),
                      icon: const Icon(Icons.info_outline_rounded),
                      tooltip: '저장 위치 자세히 보기',
                    ),
                  ],
                );
              }
              final flow = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FlowStep(
                    icon: Icons.add_rounded,
                    label: '자료 추가',
                    selected: currentStep == LearningDataStep.add,
                    onTap: onAdd,
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                  _FlowStep(
                    icon: Icons.folder_copy_outlined,
                    label: '그룹 정리',
                    selected: currentStep == LearningDataStep.organize,
                    onTap: onOrganize,
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                  _FlowStep(
                    icon: Icons.school_outlined,
                    label: '암기·퀴즈',
                    selected: currentStep == LearningDataStep.learn,
                    onTap: onLearn,
                  ),
                ],
              );
              final compactFlow = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FlowStep(
                    icon: Icons.add_rounded,
                    label: '1 자료 추가',
                    selected: currentStep == LearningDataStep.add,
                    onTap: onAdd,
                  ),
                  _FlowStep(
                    icon: Icons.folder_copy_outlined,
                    label: '2 그룹 정리',
                    selected: currentStep == LearningDataStep.organize,
                    onTap: onOrganize,
                  ),
                  _FlowStep(
                    icon: Icons.school_outlined,
                    label: '3 암기·퀴즈',
                    selected: currentStep == LearningDataStep.learn,
                    onTap: onLearn,
                  ),
                ],
              );
              final details = TextButton.icon(
                key: const Key('open-learning-data-details'),
                onPressed: () => _showStorageDetails(context),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('저장 구조'),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: compactFlow),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('open-learning-data-details-compact'),
                          onPressed: () => _showStorageDetails(context),
                          icon: const Icon(Icons.info_outline_rounded),
                          tooltip: '저장 위치 자세히 보기',
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: title),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: flow),
                  const SizedBox(width: 10),
                  details,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showStorageDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '내 학습 데이터는 어디에 있나요?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '그룹을 바꾸거나 옮겨도 원본 자료와 학습 기록은 그대로 남습니다. '
                  '그룹은 같은 자료를 원하는 방식으로 묶어 보는 정리 도구예요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                const _StorageRow(
                  icon: Icons.inventory_2_outlined,
                  title: '앱 기본 자료',
                  detail: '앱에 처음부터 들어 있으며, 직접 고치기 전까지 원본 그대로 유지됩니다.',
                ),
                const _StorageRow(
                  icon: Icons.phone_android_rounded,
                  title: '이 기기의 로컬 데이터베이스',
                  detail: '직접 만든 자료, 그룹, 진도, 일정과 XP는 항상 이 기기에 먼저 저장됩니다.',
                ),
                _StorageRow(
                  icon: localFolderConfigured
                      ? Icons.folder_copy_outlined
                      : Icons.create_new_folder_outlined,
                  title: '사용자 관리 로컬 폴더',
                  detail: localFolderConfigured
                      ? driveConnected
                            ? '${localFolderName ?? 'Sprache'}는 Drive 연결 해제 시 자동으로 복귀할 대기 위치입니다.'
                            : '${localFolderName ?? 'Sprache'}에 정돈된 학습 데이터의 검증 사본을 자동 보관합니다.'
                      : '설정 > 저장·동기화에서 Drive 없이 쓸 로컬 폴더를 선택할 수 있습니다.',
                ),
                _StorageRow(
                  icon: driveConnected
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  title: 'Google Drive',
                  detail: driveConnected
                      ? '사용자가 고른 WordStudyData 폴더와 이 기기의 변경 내용을 맞춥니다.'
                      : '설정 > 저장·동기화에서 연결할 수 있으며, 연결하지 않아도 학습할 수 있습니다.',
                ),
                const _StorageRow(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Drive의 숨김 연결 정보',
                  detail: '선택한 폴더의 ID와 이름만 내 Drive에 보관합니다. 별도 서버는 쓰지 않습니다.',
                  last: true,
                ),
                if (!driveConnected && onManageStorage != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onManageStorage?.call();
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(
                      localFolderConfigured ? '저장 위치 설정 열기' : '로컬 폴더 선택',
                    ),
                  ),
                ],
                if (driveConnected) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (syncBusy)
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.sync_rounded, size: 20),
                        const SizedBox(width: 9),
                        Expanded(child: Text(syncLabel ?? 'Drive 상태 확인 중')),
                        if (onSync != null)
                          TextButton(
                            onPressed: syncBusy
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    onSync?.call();
                                  },
                            child: const Text('지금 동기화'),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _compactFlowLabel => switch (currentStep) {
    LearningDataStep.add => '① 자료 추가 → 그룹 → 학습',
    LearningDataStep.organize => '자료 추가 → ② 그룹 → 학습',
    LearningDataStep.learn => '자료 추가 → 그룹 → ③ 학습',
    null => '자료 추가 → 그룹 → 학습',
  };

  String get _storageSummaryLabel => driveConnected
      ? '현재: Drive · 앱 DB 원본'
      : localFolderConfigured
      ? '현재: 로컬 폴더 · 앱 DB 원본'
      : '현재: 앱 내부 저장 · 폴더 선택 필요';

  String get _recommendedTitle => switch (currentStep) {
    LearningDataStep.add => '다음 할 일 · 자료 추가',
    LearningDataStep.organize => '다음 할 일 · 그룹 정리',
    LearningDataStep.learn => '다음 할 일 · 암기·퀴즈',
    null => '자료 추가 → 그룹 정리 → 학습',
  };
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer
          : colors.surface.withValues(alpha: 0.8),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? colors.primary : colors.secondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 42,
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
