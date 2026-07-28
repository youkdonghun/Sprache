import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_path.dart';
import '../domain/study_preferences.dart';
import '../domain/study_session_builder.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';

class SessionBuilderScreen extends ConsumerStatefulWidget {
  const SessionBuilderScreen({super.key});

  @override
  ConsumerState<SessionBuilderScreen> createState() =>
      _SessionBuilderScreenState();
}

class _SessionBuilderScreenState extends ConsumerState<SessionBuilderScreen> {
  static const _exerciseModes = [
    StudyMode.mixed,
    StudyMode.meaning,
    StudyMode.production,
    StudyMode.cloze,
    StudyMode.sentenceOrder,
    StudyMode.listening,
  ];
  static const _itemLimits = [5, 10, 15, 20, 30];

  var _plan = const StudySessionPlan();
  var _initialized = false;

  void _setPlan(StudySessionPlan plan) {
    setState(() => _plan = plan);
  }

  void _toggleKind({required bool words, required bool selected}) {
    final includeWords = words ? selected : _plan.includeWords;
    final includeSentences = words ? _plan.includeSentences : selected;
    if (!includeWords && !includeSentences) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어와 문장 중 하나는 반드시 포함해야 합니다.')),
      );
      return;
    }
    _setPlan(
      _plan.copyWith(
        includeWords: includeWords,
        includeSentences: includeSentences,
      ),
    );
  }

  void _savePlan() {
    ref.read(appControllerProvider.notifier).updateSessionPlan(_plan);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('이 세션 설정을 기기에 저장했습니다.')));
  }

  void _start(StudySessionBuildResult preview) {
    if (preview.isEmpty) return;
    ref.read(appControllerProvider.notifier).updateSessionPlan(_plan);
    context.push('/study?mode=${_plan.mode.name}&custom=true');
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    if (!_initialized && appState.isHydrated) {
      _plan = appState.preferences.sessionPlan;
      _initialized = true;
    }
    final preview = controller.previewSessionPlan(
      _plan,
      ref.read(appClockProvider)(),
    );
    final units = controller.coursePath.units;
    final tags = controller.availableSessionTags;
    final levels = controller.availableSessionLevels;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final padding = constraints.maxWidth < 620 ? 18.0 : 28.0;
          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BuilderSection(
                number: '1',
                title: '어떻게 기억을 꺼낼까요?',
                description: '한 세션에서는 하나의 문제 흐름을 사용합니다.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in _exerciseModes)
                      ChoiceChip(
                        key: Key('session-mode-${mode.name}'),
                        label: Text(mode.label),
                        selected: _plan.mode == mode,
                        onSelected: (_) => _setPlan(_plan.copyWith(mode: mode)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '2',
                title: '어떤 덱에서 가져올까요?',
                description: '코스 전체, 단원, 별표, 직접 추가한 표현을 분리해 연습합니다.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, sectionConstraints) {
                        final columns = sectionConstraints.maxWidth >= 660
                            ? 2
                            : 1;
                        final width =
                            (sectionConstraints.maxWidth - (columns - 1) * 10) /
                            columns;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final deck in StudyDeckScope.values)
                              SizedBox(
                                width: width,
                                child: _DeckChoice(
                                  deck: deck,
                                  selected: _plan.deck == deck,
                                  onTap: () =>
                                      _setPlan(_plan.copyWith(deck: deck)),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (_plan.deck == StudyDeckScope.unit) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        key: ValueKey('session-unit-${_plan.unitIndex}'),
                        initialValue: _plan.unitIndex ?? 0,
                        decoration: const InputDecoration(
                          labelText: '단원 덱',
                          prefixIcon: Icon(Icons.route_rounded),
                        ),
                        items: [
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit.index,
                              child: Text(
                                'Unit ${unit.index + 1} · ${unit.title}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _setPlan(_plan.copyWith(unitIndex: value));
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '3',
                title: '현재 기억 단계',
                description: '학습 기록을 기준으로 필요한 난이도만 고릅니다.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final difficulty in StudyDifficulty.values)
                      ChoiceChip(
                        key: Key('session-difficulty-${difficulty.name}'),
                        label: Text(difficulty.label),
                        selected: _plan.difficulty == difficulty,
                        onSelected: (_) =>
                            _setPlan(_plan.copyWith(difficulty: difficulty)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '4',
                title: '단어와 문장 구성',
                description: '세션 길이와 문장 비율을 실제 출제 목록에 반영합니다.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          key: const Key('session-include-words'),
                          avatar: const Icon(
                            Icons.text_fields_rounded,
                            size: 18,
                          ),
                          label: const Text('단어 포함'),
                          selected: _plan.includeWords,
                          onSelected: (selected) =>
                              _toggleKind(words: true, selected: selected),
                        ),
                        FilterChip(
                          key: const Key('session-include-sentences'),
                          avatar: const Icon(Icons.notes_rounded, size: 18),
                          label: const Text('문장 포함'),
                          selected: _plan.includeSentences,
                          onSelected: (selected) =>
                              _toggleKind(words: false, selected: selected),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('문제 수', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final limit in _itemLimits)
                          ChoiceChip(
                            key: Key('session-limit-$limit'),
                            label: Text('$limit개'),
                            selected: _plan.itemLimit == limit,
                            onSelected: (_) =>
                                _setPlan(_plan.copyWith(itemLimit: limit)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '문장 문제 비율',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          _plan.includeWords && _plan.includeSentences
                              ? '${(_plan.sentenceRatio * 100).round()}%'
                              : _plan.includeSentences
                              ? '문장만'
                              : '단어만',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    Slider(
                      key: const Key('session-sentence-ratio'),
                      value: _plan.sentenceRatio,
                      divisions: 10,
                      label: '${(_plan.sentenceRatio * 100).round()}%',
                      onChanged: _plan.includeWords && _plan.includeSentences
                          ? (value) =>
                                _setPlan(_plan.copyWith(sentenceRatio: value))
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '5',
                title: '레벨과 태그',
                description: '선택하지 않으면 모든 레벨과 태그를 포함합니다.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterChoices(
                      label: '콘텐츠 레벨',
                      emptyLabel: '현재 코스에 레벨 정보가 없습니다.',
                      values: levels,
                      selected: _plan.levels,
                      keyPrefix: 'session-level',
                      onChanged: (selected) =>
                          _setPlan(_plan.copyWith(levels: selected)),
                    ),
                    const SizedBox(height: 18),
                    _FilterChoices(
                      label: '태그 · 여러 개 선택 시 하나라도 일치',
                      emptyLabel: '현재 코스에 선택할 태그가 없습니다.',
                      values: tags,
                      selected: _plan.tags,
                      keyPrefix: 'session-tag',
                      onChanged: (selected) =>
                          _setPlan(_plan.copyWith(tags: selected)),
                    ),
                  ],
                ),
              ),
            ],
          );

          return SingleChildScrollView(
            key: const Key('session-builder-scroll'),
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      languageName: appState.selectedLanguage.koreanName,
                      onBack: () => context.go('/learn'),
                      onReset: () => _setPlan(const StudySessionPlan()),
                    ),
                    const SizedBox(height: 18),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: editor),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 340,
                            child: _PreviewCard(
                              plan: _plan,
                              preview: preview,
                              units: units,
                              onSave: _savePlan,
                              onStart: () => _start(preview),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _PreviewCard(
                        plan: _plan,
                        preview: preview,
                        units: units,
                        onSave: _savePlan,
                        onStart: () => _start(preview),
                      ),
                      const SizedBox(height: 14),
                      editor,
                      const SizedBox(height: 18),
                      _BottomActions(
                        preview: preview,
                        onSave: _savePlan,
                        onStart: () => _start(preview),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.languageName,
    required this.onBack,
    required this.onReset,
  });

  final String languageName;
  final VoidCallback onBack;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const Key('session-builder-back'),
          onPressed: onBack,
          tooltip: '학습실로',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '나만의 학습 세션',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '$languageName 코스에서 필요한 표현과 문제 방식만 조합하세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          key: const Key('session-builder-reset'),
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('초기화'),
        ),
      ],
    );
  }
}

class _BuilderSection extends StatelessWidget {
  const _BuilderSection({
    required this.number,
    required this.title,
    required this.description,
    required this.child,
  });

  final String number;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    number,
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeckChoice extends StatelessWidget {
  const _DeckChoice({
    required this.deck,
    required this.selected,
    required this.onTap,
  });

  final StudyDeckScope deck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('session-deck-${deck.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(switch (deck) {
                StudyDeckScope.course => Icons.language_rounded,
                StudyDeckScope.unit => Icons.view_module_rounded,
                StudyDeckScope.favorites => Icons.star_rounded,
                StudyDeckScope.personal => Icons.person_rounded,
              }, color: selected ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deck.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChoices extends StatelessWidget {
  const _FilterChoices({
    required this.label,
    required this.emptyLabel,
    required this.values,
    required this.selected,
    required this.keyPrefix,
    required this.onChanged,
  });

  final String label;
  final String emptyLabel;
  final List<String> values;
  final Set<String> selected;
  final String keyPrefix;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (values.isEmpty)
          Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                FilterChip(
                  key: Key('$keyPrefix-$value'),
                  label: Text(value),
                  selected: selected.contains(value),
                  onSelected: (isSelected) {
                    final next = {...selected};
                    if (isSelected) {
                      next.add(value);
                    } else {
                      next.remove(value);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.plan,
    required this.preview,
    required this.units,
    required this.onSave,
    required this.onStart,
  });

  final StudySessionPlan plan;
  final StudySessionBuildResult preview;
  final List<CourseUnitSnapshot> units;
  final VoidCallback onSave;
  final VoidCallback onStart;

  String get _deckLabel {
    if (plan.deck != StudyDeckScope.unit) return plan.deck.label;
    final index = plan.unitIndex ?? 0;
    final unit = units.where((value) => value.index == index).firstOrNull;
    return unit == null ? '단원 덱' : 'Unit ${unit.index + 1} · ${unit.title}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = math.max(1, (preview.items.length * 0.6).ceil());
    return Card(
      key: const Key('session-preview'),
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview.isEmpty ? '조건에 맞는 표현이 없어요' : '이 설정으로 바로 시작',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preview.isEmpty
                  ? '덱·난이도·태그 또는 단어/문장 조건을 하나씩 넓혀 보세요.'
                  : '후보 ${preview.matchingCount}개 중 ${preview.items.length}개를 학습합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PreviewMetric(
                    value: '${preview.items.length}',
                    label: '문제',
                  ),
                ),
                Expanded(
                  child: _PreviewMetric(
                    value: '${preview.selectedWordCount}',
                    label: '단어',
                  ),
                ),
                Expanded(
                  child: _PreviewMetric(
                    value: '${preview.selectedSentenceCount}',
                    label: '문장',
                  ),
                ),
                Expanded(
                  child: _PreviewMetric(value: '$minutes분', label: '예상'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _PreviewPill(label: _deckLabel),
                _PreviewPill(label: plan.mode.label),
                _PreviewPill(label: plan.difficulty.label),
                if (plan.tags.isNotEmpty)
                  _PreviewPill(label: '태그 ${plan.tags.length}개'),
                if (plan.levels.isNotEmpty)
                  _PreviewPill(label: '레벨 ${plan.levels.length}개'),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('session-start'),
              onPressed: preview.isEmpty ? null : onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: colors.onPrimaryContainer,
                foregroundColor: colors.primaryContainer,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('${preview.items.length}문제 시작'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('session-save'),
              onPressed: onSave,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: colors.onPrimaryContainer,
                side: BorderSide(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.5),
                ),
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('이 설정 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.preview,
    required this.onSave,
    required this.onStart,
  });

  final StudySessionBuildResult preview;
  final VoidCallback onSave;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('session-actions-bottom'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview.isEmpty
                  ? '조건을 조정하면 여기서 시작할 수 있어요.'
                  : '설정 완료 · ${preview.items.length}문제',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('session-start-bottom'),
              onPressed: preview.isEmpty ? null : onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('${preview.items.length}문제 시작'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('session-save-bottom'),
              onPressed: onSave,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('이 설정 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
