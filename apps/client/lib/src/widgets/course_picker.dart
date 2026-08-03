import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../domain/language.dart';
import '../domain/study_subject.dart';
import '../services/app_feedback_service.dart';
import '../state/app_state.dart';
import '../state/device_preferences_state.dart';

/// Selects both built-in language courses and user-defined study subjects.
///
/// The historical class name is kept so existing screens and routes remain
/// source-compatible while the product grows beyond language learning.
class CoursePicker extends ConsumerWidget {
  const CoursePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final activeSubjectId = state.activeSubjectId;
    final controller = ref.read(appControllerProvider.notifier);
    final subjects = controller.availableSubjects;
    final hasHiddenSubjects = controller.hiddenSubjects.isNotEmpty;
    final textScaler = MediaQuery.textScalerOf(context);
    final toolbarTextExpansion =
        (textScaler.scale(14) - 14) + (textScaler.scale(12) - 12);
    final toolbarHeight =
        48.0 + (toolbarTextExpansion > 0 ? toolbarTextExpansion * 1.1 : 0.0);
    void emitSelection() => unawaited(
      AppFeedbackService(
        readPreferences: () =>
            ref.read(appControllerProvider).preferences.experience,
        readDevicePreferences: () =>
            ref.read(devicePreferencesControllerProvider).preferences.voice,
      ).selection(),
    );

    KeyEventResult handleKey(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent || subjects.isEmpty) {
        return KeyEventResult.ignored;
      }
      final currentIndex = subjects.indexWhere(
        (subject) => subject.id == activeSubjectId,
      );
      final safeIndex = currentIndex < 0 ? 0 : currentIndex;
      int? nextIndex;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        nextIndex = (safeIndex - 1).clamp(0, subjects.length - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        nextIndex = (safeIndex + 1).clamp(0, subjects.length - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.home) {
        nextIndex = 0;
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        nextIndex = subjects.length - 1;
      }
      if (nextIndex == null) return KeyEventResult.ignored;
      emitSelection();
      controller.selectSubject(subjects[nextIndex].id);
      return KeyEventResult.handled;
    }

    return Focus(
      key: const Key('study-subject-keyboard-navigation'),
      onKeyEvent: handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('study-subject-toolbar'),
            height: toolbarHeight,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '학습 주제',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '선택하면 자료와 학습 문제가 함께 바뀝니다.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _NewSubjectButton(
                  onPressed: () => _showSubjectEditor(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _ScrollableSubjectRail(
            key: const ValueKey('study-subject-picker'),
            itemCount: subjects.length + (hasHiddenSubjects ? 1 : 0),
            itemBuilder: (context, index) {
              if (hasHiddenSubjects && index == 1) {
                return _HiddenSubjectsCard(
                  count: controller.hiddenSubjects.length,
                  onTap: () => _showHiddenSubjects(context, ref),
                );
              }
              final subjectIndex = hasHiddenSubjects && index > 1
                  ? index - 1
                  : index;
              final subject = subjects[subjectIndex];
              return _SubjectCard(
                subject: subject,
                selected: subject.id == activeSubjectId,
                onSelect: () {
                  emitSelection();
                  controller.selectSubject(subject.id);
                },
                onEdit: () => _showSubjectActions(context, ref, subject),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showSubjectPicker(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(appControllerProvider);
        final controller = ref.read(appControllerProvider.notifier);
        final subjects = controller.availableSubjects;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              maxWidth: 620,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '학습 주제 바꾸기',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '선택한 주제의 자료와 진도가 모든 화면에 적용됩니다.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const Key(
                          'create-study-subject-from-shell-picker',
                        ),
                        tooltip: '새 학습 주제 만들기',
                        onPressed: () async {
                          await _showSubjectEditor(sheetContext, ref);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    key: const Key('shell-subject-options'),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final selected = subject.id == state.activeSubjectId;
                      return Semantics(
                        selected: selected,
                        button: true,
                        child: ListTile(
                          key: Key('shell-subject-${subject.id}'),
                          selected: selected,
                          leading: CircleAvatar(child: Text(subject.symbol)),
                          title: Text(subject.name),
                          subtitle: Text(
                            subject.isLanguage
                                ? subject.contentLanguage.nativeName
                                : subject.contentLanguage.koreanName,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () {
                            unawaited(
                              AppFeedbackService(
                                readPreferences: () => ref
                                    .read(appControllerProvider)
                                    .preferences
                                    .experience,
                                readDevicePreferences: () => ref
                                    .read(devicePreferencesControllerProvider)
                                    .preferences
                                    .voice,
                              ).selection(),
                            );
                            controller.selectSubject(subject.id);
                            Navigator.pop(sheetContext);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ScrollableSubjectRail extends StatefulWidget {
  const _ScrollableSubjectRail({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_ScrollableSubjectRail> createState() => _ScrollableSubjectRailState();
}

class _ScrollableSubjectRailState extends State<_ScrollableSubjectRail> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollBackward = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollActions);
    _scheduleScrollActionUpdate();
  }

  @override
  void didUpdateWidget(covariant _ScrollableSubjectRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleScrollActionUpdate();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateScrollActions)
      ..dispose();
    super.dispose();
  }

  void _scheduleScrollActionUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollActions();
    });
  }

  void _updateScrollActions() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBackward = position.pixels > position.minScrollExtent + 1;
    final canScrollForward = position.pixels < position.maxScrollExtent - 1;
    if (canScrollBackward == _canScrollBackward &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBackward = canScrollBackward;
      _canScrollForward = canScrollForward;
    });
  }

  Future<void> _scrollBy(double direction) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distance = (position.viewportDimension * 0.78).clamp(180.0, 420.0);
    final target = (position.pixels + (distance * direction)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      final delta =
          scrollEvent.scrollDelta.dx.abs() > scrollEvent.scrollDelta.dy.abs()
          ? scrollEvent.scrollDelta.dx
          : scrollEvent.scrollDelta.dy;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textHeightExpansion =
        (textScaler.scale(13) - 13) + (textScaler.scale(12) - 12);
    final railHeight =
        64.0 + (textHeightExpansion > 0 ? textHeightExpansion : 0.0);

    return SizedBox(
      height: railHeight,
      child: Row(
        children: [
          _SubjectRailButton(
            key: const Key('study-subject-scroll-previous'),
            icon: Icons.chevron_left_rounded,
            tooltip: '이전 주제',
            onPressed: _canScrollBackward ? () => _scrollBy(-1) : null,
          ),
          Expanded(
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: ScrollConfiguration(
                behavior: const _SubjectRailScrollBehavior(),
                child: ListView.separated(
                  key: const Key('study-subject-list'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: widget.itemCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: widget.itemBuilder,
                ),
              ),
            ),
          ),
          _SubjectRailButton(
            key: const Key('study-subject-scroll-next'),
            icon: Icons.chevron_right_rounded,
            tooltip: '다음 주제',
            onPressed: _canScrollForward ? () => _scrollBy(1) : null,
          ),
        ],
      ),
    );
  }
}

class _SubjectRailButton extends StatelessWidget {
  const _SubjectRailButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class _SubjectRailScrollBehavior extends MaterialScrollBehavior {
  const _SubjectRailScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.selected,
    required this.onSelect,
    this.onEdit,
  });

  final StudySubject subject;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final symbolOption = _subjectSymbolOptionFor(subject.symbol);
    final subtitle = subject.isLanguage
        ? subject.contentLanguage.nativeName
        : subject.contentLanguage.koreanName;
    return Semantics(
      key: Key('study-subject-${subject.id}'),
      button: true,
      selected: selected,
      label: '${subject.name} 학습 주제${selected ? ', 선택됨' : ''}',
      child: Tooltip(
        message: subject.description.isEmpty
            ? subject.name
            : subject.description,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onSelect,
            child: Container(
              width: subject.isLanguage ? 158 : 174,
              padding: EdgeInsets.fromLTRB(9, 7, onEdit == null ? 9 : 5, 7),
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SizedBox.square(
                      dimension: subject.isLanguage ? 32 : 36,
                      child: Center(
                        child: symbolOption != null
                            ? Icon(
                                symbolOption.icon,
                                size: 20,
                                color: selected
                                    ? colors.onPrimary
                                    : colors.onSurfaceVariant,
                              )
                            : Text(
                                subject.symbol,
                                style: TextStyle(
                                  color: selected
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                  fontSize: subject.isLanguage ? 12 : 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      key: Key('edit-study-subject-${subject.id}'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      tooltip: '주제 관리',
                      onPressed: onEdit,
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewSubjectButton extends StatelessWidget {
  const _NewSubjectButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '새 학습 주제 만들기',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: IconButton.filledTonal(
          key: const Key('create-study-subject'),
          tooltip: '새 주제',
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _HiddenSubjectsCard extends StatelessWidget {
  const _HiddenSubjectsCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '숨긴 학습 주제 $count개 복원',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('restore-hidden-study-subjects'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.visibility_off_rounded,
                    color: colors.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '숨긴 주제 $count',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
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

Future<void> _showSubjectActions(
  BuildContext context,
  WidgetRef ref,
  StudySubject subject,
) async {
  final controller = ref.read(appControllerProvider.notifier);
  final hasOverride = controller.hasStudySubjectOverride(subject.id);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(subject.symbol)),
              title: Text(
                subject.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(subject.isLanguage ? '기본 언어 주제' : '사용자 학습 주제'),
            ),
            ListTile(
              key: Key('edit-study-subject-action-${subject.id}'),
              leading: const Icon(Icons.edit_rounded),
              title: const Text('이름·기호·설명 수정'),
              subtitle: const Text('학습 자료와 진도는 그대로 유지됩니다.'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSubjectEditor(context, ref, existing: subject);
              },
            ),
            if (subject.isLanguage && hasOverride)
              ListTile(
                key: Key('reset-study-subject-action-${subject.id}'),
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('기본 표시로 되돌리기'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await controller.resetStudySubjectOverride(subject.id);
                },
              ),
            ListTile(
              key: Key('delete-study-subject-action-${subject.id}'),
              leading: Icon(
                Icons.visibility_off_rounded,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                '주제 숨기기',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text('자료를 지우지 않고 목록에서만 숨깁니다.'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmHideSubject(context, ref, subject);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmHideSubject(
  BuildContext context,
  WidgetRef ref,
  StudySubject subject,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('“${subject.name}” 주제를 숨길까요?'),
      content: const Text(
        '등록한 단어·문장·학습 진도는 삭제하지 않습니다. '
        '주제 목록의 “숨긴 주제”에서 언제든 다시 복원할 수 있습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-hide-study-subject'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('숨기기'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(appControllerProvider.notifier).hideStudySubject(subject.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('“${subject.name}” 주제를 숨겼습니다. 자료는 유지됩니다.')),
    );
  } on FormatException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}

Future<void> _showHiddenSubjects(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(appControllerProvider.notifier);
  final hidden = controller.hiddenSubjects;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text('숨긴 주제', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('복원하면 자료와 이전 학습 진도를 그대로 다시 사용할 수 있습니다.'),
            const SizedBox(height: 10),
            for (final subject in hidden)
              ListTile(
                key: Key('restore-study-subject-${subject.id}'),
                leading: CircleAvatar(child: Text(subject.symbol)),
                title: Text(subject.name),
                subtitle: Text(subject.description),
                trailing: const Icon(Icons.restore_rounded),
                onTap: () async {
                  await controller.restoreStudySubject(subject.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showSubjectEditor(
  BuildContext context,
  WidgetRef ref, {
  StudySubject? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final descriptionController = TextEditingController(
    text: existing?.description ?? '',
  );
  final symbolController = TextEditingController(
    text: _normalizePresetSubjectSymbol(existing?.symbol ?? '책'),
  );
  var contentLanguage = existing?.contentLanguage ?? LanguageTag.korean;
  var symbolCategoryId = _subjectSymbolCategoryFor(symbolController.text).id;
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<StudySubject>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? '새 학습 주제' : '학습 주제 수정'),
        content: Form(
          key: formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing?.isLanguage == true
                        ? '표시 이름과 기호를 바꿔도 기본 언어 자료와 학습 진도는 그대로 유지됩니다.'
                        : '언어뿐 아니라 자격증, 스포츠, 업무, 취미처럼 외우고 싶은 내용을 한 주제로 묶습니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('study-subject-name'),
                    controller: nameController,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '주제 이름',
                      hintText: '예: 야구 용어, 아이돌 상식, 산업안전기사',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '주제 이름을 입력해 주세요.';
                      if (text.runes.length > 60) return '60자 이하로 입력해 주세요.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('study-subject-description'),
                    controller: descriptionController,
                    maxLength: 240,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '설명',
                      hintText: '이 주제에서 무엇을 외울지 적어 두세요.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SubjectSymbolPicker(
                    selectedSymbol: symbolController.text,
                    categoryId: symbolCategoryId,
                    onCategorySelected: (categoryId) {
                      setState(() => symbolCategoryId = categoryId);
                    },
                    onSymbolSelected: (symbol) {
                      symbolController.text = symbol;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 104,
                        child: TextFormField(
                          key: const Key('study-subject-symbol'),
                          controller: symbolController,
                          maxLength: 4,
                          decoration: const InputDecoration(
                            labelText: '직접 입력',
                            hintText: 'ABC',
                            helperText: '최대 4자',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return '필수';
                            if (text.runes.length > 4) return '4자 이하';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<LanguageTag>(
                          key: const Key('study-subject-language'),
                          initialValue: contentLanguage,
                          decoration: const InputDecoration(
                            labelText: '자료의 기본 언어',
                            helperText: '읽기·발음·정답 처리에 사용',
                          ),
                          items: [
                            for (final language in LanguageTag.values)
                              DropdownMenuItem(
                                value: language,
                                child: Text(language.koreanName),
                              ),
                          ],
                          onChanged: existing?.isLanguage == true
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => contentLanguage = value);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('save-study-subject'),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final now = DateTime.now().toUtc();
              final name = nameController.text.trim();
              Navigator.pop(
                dialogContext,
                StudySubject(
                  id: existing?.id ?? _newSubjectId(name, now),
                  kind: existing?.kind ?? StudySubjectKind.general,
                  name: name,
                  description: descriptionController.text.trim(),
                  symbol: symbolController.text.trim(),
                  contentLanguage: contentLanguage,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                ),
              );
            },
            child: Text(existing == null ? '주제 만들기' : '수정 저장'),
          ),
        ],
      ),
    ),
  );
  // showDialog completes when pop starts; keep controllers alive until the
  // dialog route's exit animation has detached its text fields.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  nameController.dispose();
  descriptionController.dispose();
  symbolController.dispose();
  if (result == null || !context.mounted) return;
  try {
    await ref.read(appControllerProvider.notifier).upsertStudySubject(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? '“${result.name}” 주제를 만들었습니다.'
              : '“${result.name}” 주제를 수정했습니다.',
        ),
      ),
    );
  } on FormatException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class _SubjectSymbolOption {
  const _SubjectSymbolOption(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class _SubjectSymbolCategory {
  const _SubjectSymbolCategory(this.id, this.label, this.options);

  final String id;
  final String label;
  final List<_SubjectSymbolOption> options;
}

const _subjectSymbolCategories = <_SubjectSymbolCategory>[
  _SubjectSymbolCategory('study', '학습', [
    _SubjectSymbolOption('책', '책·자료', Icons.menu_book_rounded),
    _SubjectSymbolOption('암', '암기', Icons.psychology_alt_rounded),
    _SubjectSymbolOption('말', '말하기', Icons.record_voice_over_rounded),
    _SubjectSymbolOption('듣', '듣기', Icons.headphones_rounded),
    _SubjectSymbolOption('쓰', '쓰기', Icons.edit_rounded),
    _SubjectSymbolOption('문', '문장', Icons.notes_rounded),
    _SubjectSymbolOption('복', '복습', Icons.replay_rounded),
    _SubjectSymbolOption('단', '단어', Icons.translate_rounded),
  ]),
  _SubjectSymbolCategory('exam', '시험', [
    _SubjectSymbolOption('목표', '목표', Icons.flag_rounded),
    _SubjectSymbolOption('합', '합격', Icons.verified_rounded),
    _SubjectSymbolOption('시험', '문제 풀이', Icons.quiz_rounded),
    _SubjectSymbolOption('점', '점수', Icons.grade_rounded),
    _SubjectSymbolOption('일정', '시험 일정', Icons.event_rounded),
    _SubjectSymbolOption('때', '시간', Icons.timer_rounded),
    _SubjectSymbolOption('집중', '집중', Icons.local_fire_department_rounded),
    _SubjectSymbolOption('중요', '중요', Icons.star_rounded),
  ]),
  _SubjectSymbolCategory('work', '업무', [
    _SubjectSymbolOption('업', '업무', Icons.work_rounded),
    _SubjectSymbolOption('컴', '컴퓨터', Icons.computer_rounded),
    _SubjectSymbolOption('표', '통계', Icons.bar_chart_rounded),
    _SubjectSymbolOption('계산', '회계', Icons.receipt_long_rounded),
    _SubjectSymbolOption('회사', '회사', Icons.business_rounded),
    _SubjectSymbolOption('핀', '메모', Icons.push_pin_rounded),
    _SubjectSymbolOption('협업', '협업', Icons.handshake_rounded),
    _SubjectSymbolOption('설정', '기술', Icons.settings_rounded),
  ]),
  _SubjectSymbolCategory('travel', '여행', [
    _SubjectSymbolOption('비행', '비행기', Icons.flight_rounded),
    _SubjectSymbolOption('지도', '지도', Icons.map_rounded),
    _SubjectSymbolOption('짐', '여행 가방', Icons.luggage_rounded),
    _SubjectSymbolOption('숙소', '숙소', Icons.hotel_rounded),
    _SubjectSymbolOption('열차', '기차', Icons.train_rounded),
    _SubjectSymbolOption('차량', '자동차', Icons.directions_car_rounded),
    _SubjectSymbolOption('세계', '세계', Icons.public_rounded),
    _SubjectSymbolOption('탐험', '탐험', Icons.explore_rounded),
  ]),
  _SubjectSymbolCategory('sports', '스포츠', [
    _SubjectSymbolOption('야구', '야구', Icons.sports_baseball_rounded),
    _SubjectSymbolOption('축구', '축구', Icons.sports_soccer_rounded),
    _SubjectSymbolOption('농구', '농구', Icons.sports_basketball_rounded),
    _SubjectSymbolOption('배구', '배구', Icons.sports_volleyball_rounded),
    _SubjectSymbolOption('테니스', '테니스', Icons.sports_tennis_rounded),
    _SubjectSymbolOption('라켓', '라켓 운동', Icons.sports_rounded),
    _SubjectSymbolOption('수영', '수영', Icons.pool_rounded),
    _SubjectSymbolOption('자전', '자전거', Icons.directions_bike_rounded),
  ]),
  _SubjectSymbolCategory('culture', '문화', [
    _SubjectSymbolOption('음악', '음악', Icons.music_note_rounded),
    _SubjectSymbolOption('마이크', '노래', Icons.mic_rounded),
    _SubjectSymbolOption('영화', '영화', Icons.movie_rounded),
    _SubjectSymbolOption('미술', '미술', Icons.palette_rounded),
    _SubjectSymbolOption('사진', '사진', Icons.photo_camera_rounded),
    _SubjectSymbolOption('게임', '게임', Icons.sports_esports_rounded),
    _SubjectSymbolOption('독서', '독서', Icons.auto_stories_rounded),
    _SubjectSymbolOption('연극', '공연', Icons.theater_comedy_rounded),
  ]),
  _SubjectSymbolCategory('daily', '생활', [
    _SubjectSymbolOption('집', '집', Icons.home_rounded),
    _SubjectSymbolOption('요리', '요리', Icons.restaurant_rounded),
    _SubjectSymbolOption('카페', '카페', Icons.coffee_rounded),
    _SubjectSymbolOption('식사', '식사', Icons.lunch_dining_rounded),
    _SubjectSymbolOption('장', '장보기', Icons.shopping_cart_rounded),
    _SubjectSymbolOption('돈', '금융', Icons.payments_rounded),
    _SubjectSymbolOption('건강', '건강', Icons.favorite_rounded),
    _SubjectSymbolOption('식물', '식물', Icons.spa_rounded),
  ]),
  _SubjectSymbolCategory('science', '과학', [
    _SubjectSymbolOption('과학', '과학', Icons.science_rounded),
    _SubjectSymbolOption('실험', '실험', Icons.biotech_rounded),
    _SubjectSymbolOption('수학', '수학', Icons.calculate_rounded),
    _SubjectSymbolOption('아이디어', '아이디어', Icons.lightbulb_rounded),
    _SubjectSymbolOption('우주', '우주', Icons.rocket_launch_rounded),
    _SubjectSymbolOption('탐사', '탐사', Icons.travel_explore_rounded),
    _SubjectSymbolOption('유전', '유전·구조', Icons.account_tree_rounded),
    _SubjectSymbolOption('로봇', '로봇', Icons.smart_toy_rounded),
  ]),
];

const _legacySubjectSymbolAliases = <String, String>{
  '📚': '책',
  '🎯': '목표',
  '💼': '업',
  '✈️': '비행',
  '⚾': '야구',
  '🎵': '음악',
  '🎤': '마이크',
  '🏠': '집',
  '🔬': '과학',
};

String _normalizePresetSubjectSymbol(String symbol) =>
    _legacySubjectSymbolAliases[symbol] ?? symbol;

_SubjectSymbolOption? _subjectSymbolOptionFor(String symbol) {
  final normalized = _normalizePresetSubjectSymbol(symbol);
  for (final category in _subjectSymbolCategories) {
    for (final option in category.options) {
      if (option.value == normalized) return option;
    }
  }
  return null;
}

_SubjectSymbolCategory _subjectSymbolCategoryFor(String symbol) {
  final normalized = _normalizePresetSubjectSymbol(symbol);
  return _subjectSymbolCategories.firstWhere(
    (category) => category.options.any((option) => option.value == normalized),
    orElse: () => _subjectSymbolCategories.first,
  );
}

class _SubjectSymbolPicker extends StatelessWidget {
  const _SubjectSymbolPicker({
    required this.selectedSymbol,
    required this.categoryId,
    required this.onCategorySelected,
    required this.onSymbolSelected,
  });

  final String selectedSymbol;
  final String categoryId;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onSymbolSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final category = _subjectSymbolCategories.firstWhere(
      (candidate) => candidate.id == categoryId,
      orElse: () => _subjectSymbolCategories.first,
    );
    final normalizedSelectedSymbol = _normalizePresetSubjectSymbol(
      selectedSymbol,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기호 선택',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          key: const Key('study-subject-symbol-categories'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final candidate in _subjectSymbolCategories)
              ChoiceChip(
                key: Key('study-subject-symbol-category-${candidate.id}'),
                label: Text(candidate.label),
                selected: candidate.id == category.id,
                onSelected: (_) => onCategorySelected(candidate.id),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in category.options)
              Semantics(
                button: true,
                selected: option.value == normalizedSelectedSymbol,
                label: '${category.label} 기호 ${option.label}',
                child: Tooltip(
                  message: option.label,
                  child: InkWell(
                    key: Key('study-subject-symbol-option-${option.value}'),
                    onTap: () => onSymbolSelected(option.value),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: option.value == normalizedSelectedSymbol
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: option.value == normalizedSelectedSymbol
                              ? colors.primary
                              : colors.outlineVariant,
                          width: option.value == normalizedSelectedSymbol
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Icon(
                        option.icon,
                        size: 22,
                        color: option.value == normalizedSelectedSymbol
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _newSubjectId(String name, DateTime now) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = now.microsecondsSinceEpoch.toRadixString(36);
  return 'general:${slug.isEmpty ? 'topic' : slug}-$suffix';
}
