import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/study_subject.dart';
import '../state/app_state.dart';
import '../state/navigation_guard_state.dart';

Future<QuickContentSaveResult?> showQuickContentSheet({
  required BuildContext context,
  LearningItemKind initialKind = LearningItemKind.word,
}) {
  return showModalBottomSheet<QuickContentSaveResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _QuickContentSheet(initialKind: initialKind),
  );
}

class _QuickContentSheet extends ConsumerStatefulWidget {
  const _QuickContentSheet({required this.initialKind});

  final LearningItemKind initialKind;

  @override
  ConsumerState<_QuickContentSheet> createState() => _QuickContentSheetState();
}

class _QuickContentSheetState extends ConsumerState<_QuickContentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _meaningController = TextEditingController();
  final _readingController = TextEditingController();
  final _exampleController = TextEditingController();
  final _exampleMeaningController = TextEditingController();
  final _newGroupController = TextEditingController();
  late LearningItemKind _kind;
  late String _cleanDraftFingerprint;
  late final NavigationGuardController _navigationGuard;
  var _partOfSpeech = PartOfSpeech.noun;
  var _saving = false;
  var _creatingGroup = false;
  var _exitDialogOpen = false;
  var _allowPop = false;
  var _suspendDraftRefresh = false;
  String? _selectedGroup;

  List<TextEditingController> get _draftControllers => [
    _textController,
    _meaningController,
    _readingController,
    _exampleController,
    _exampleMeaningController,
    _newGroupController,
  ];

  bool get _hasUnsavedChanges =>
      !_allowPop && _draftFingerprint() != _cleanDraftFingerprint;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    for (final controller in _draftControllers) {
      controller.addListener(_refreshDraftState);
    }
    _cleanDraftFingerprint = _draftFingerprint();
    _navigationGuard = ref.read(navigationGuardProvider)
      ..register(this, _confirmDiscardForNavigation);
  }

  @override
  void dispose() {
    _navigationGuard.unregister(this);
    for (final controller in _draftControllers) {
      controller
        ..removeListener(_refreshDraftState)
        ..dispose();
    }
    super.dispose();
  }

  void _refreshDraftState() {
    if (mounted && !_suspendDraftRefresh) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final subject = controller.activeSubject;
    final groups = controller.availableLearningGroups;
    final duplicate = _textController.text.trim().isEmpty
        ? null
        : controller.findContentIdentityMatch(_candidate(subject));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 560;

    return PopScope<QuickContentSaveResult>(
      key: const Key('quick-content-sheet'),
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '빠른 자료 추가',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '표현과 뜻만 입력해도 바로 저장됩니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('quick-content-close'),
                      onPressed: _saving ? null : _requestClose,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('quick-content-scroll'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<LearningItemKind>(
                          key: const Key('quick-content-kind'),
                          segments: [
                            ButtonSegment(
                              value: LearningItemKind.word,
                              icon: const Icon(Icons.text_fields_rounded),
                              label: Text(subject.isLanguage ? '단어' : '개념'),
                            ),
                            ButtonSegment(
                              value: LearningItemKind.sentence,
                              icon: const Icon(Icons.notes_rounded),
                              label: Text(subject.isLanguage ? '문장' : '사실·문장'),
                            ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (value) =>
                              setState(() => _kind = value.first),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('quick-content-text'),
                          controller: _textController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: _kind == LearningItemKind.word
                                ? subject.isLanguage
                                      ? '${subject.name} 단어'
                                      : '외울 개념·용어'
                                : subject.isLanguage
                                ? '${subject.name} 문장'
                                : '외울 사실·문장',
                            hintText: _kind == LearningItemKind.word
                                ? '예: accomplish'
                                : '예: I accomplished my goal.',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('quick-content-meaning'),
                          controller: _meaningController,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              _save(subject, keepAdding: false),
                          decoration: const InputDecoration(
                            labelText: '한국어 뜻',
                            hintText: '여러 뜻은 쉼표로 구분',
                          ),
                          validator: _required,
                        ),
                        if (duplicate != null) ...[
                          const SizedBox(height: 10),
                          _DuplicateNotice(
                            item: duplicate,
                            newMeanings: _splitValues(_meaningController.text),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          '학습 그룹 (선택)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '선택하면 저장과 동시에 그룹에 들어갑니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                key: const Key('quick-content-no-group'),
                                label: const Text('나중에 정리'),
                                selected: _selectedGroup == null,
                                onSelected: (_) =>
                                    setState(() => _selectedGroup = null),
                              ),
                              for (final group in groups) ...[
                                const SizedBox(width: 7),
                                ChoiceChip(
                                  key: Key('quick-content-group-$group'),
                                  label: Text(group),
                                  selected: _selectedGroup == group,
                                  onSelected: (_) =>
                                      setState(() => _selectedGroup = group),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('quick-content-new-group'),
                                controller: _newGroupController,
                                maxLength: 40,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _createGroup(),
                                decoration: const InputDecoration(
                                  labelText: '새 그룹 이름',
                                  counterText: '',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: const Key('quick-content-create-group'),
                              onPressed: _creatingGroup ? null : _createGroup,
                              icon: _creatingGroup
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.create_new_folder_outlined,
                                    ),
                              tooltip: '그룹 만들고 선택',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          key: const Key('quick-content-more'),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: const Text('예문·읽는 법 등 더 입력'),
                          subtitle: const Text('필요할 때만 펼쳐서 입력하세요.'),
                          children: [
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const Key('quick-content-reading'),
                              controller: _readingController,
                              decoration: const InputDecoration(
                                labelText: '읽는 법 (선택)',
                                hintText: '예: 어컴플리시, 미즈, 니 하오',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('quick-content-example'),
                              controller: _exampleController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: '예문 (선택)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('quick-content-example-meaning'),
                              controller: _exampleMeaningController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: '예문 뜻 (선택)',
                              ),
                            ),
                            if (_kind == LearningItemKind.word &&
                                subject.isLanguage) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<PartOfSpeech>(
                                key: const Key('quick-content-part-of-speech'),
                                initialValue: _partOfSpeech,
                                decoration: const InputDecoration(
                                  labelText: '품사',
                                ),
                                items: [
                                  for (final part in PartOfSpeech.values)
                                    DropdownMenuItem(
                                      value: part,
                                      child: Text(part.koreanLabel),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _partOfSpeech = value);
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (compact)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('quick-content-save-and-add'),
                          onPressed: _saving
                              ? null
                              : () => _save(subject, keepAdding: true),
                          child: const Text('저장 후 계속'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const Key('quick-content-save'),
                          onPressed: _saving
                              ? null
                              : () => _save(subject, keepAdding: false),
                          child: Text(_saving ? '저장 중…' : '저장'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('quick-content-cancel'),
                        onPressed: _saving ? null : _requestClose,
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('quick-content-save-and-add'),
                        onPressed: _saving
                            ? null
                            : () => _save(subject, keepAdding: true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('저장 후 계속 추가'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const Key('quick-content-save'),
                        onPressed: _saving
                            ? null
                            : () => _save(subject, keepAdding: false),
                        icon: const Icon(Icons.save_rounded),
                        label: Text(_saving ? '저장 중…' : '저장'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _draftFingerprint() => <Object?>[
    _kind.name,
    _partOfSpeech.name,
    _selectedGroup,
    for (final controller in _draftControllers) controller.text.trim(),
  ].join('\u001f');

  Future<void> _requestClose() async {
    if (!await _confirmDiscardForNavigation() || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscardForNavigation() async {
    if (_allowPop) return true;
    if (_saving || _exitDialogOpen || !mounted) return false;
    if (!_hasUnsavedChanges) return true;
    _exitDialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('quick-content-unsaved-dialog'),
        title: const Text('작성 중인 내용을 나갈까요?'),
        content: const Text(
          '저장하지 않은 입력 내용은 사라집니다. 계속 작성하거나, 내용을 버리고 나갈 수 있어요.',
        ),
        actions: [
          TextButton(
            key: const Key('quick-content-keep-editing'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            key: const Key('quick-content-discard-and-exit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('버리고 나가기'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || discard != true) return false;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    return mounted;
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  LearningItem _candidate(StudySubject subject) {
    final text = _textController.text.trim();
    final meanings = _splitValues(_meaningController.text);
    final sentenceTokens = _kind == LearningItemKind.sentence
        ? _tokenize(text, subject.contentLanguage)
        : const <String>[];
    final capabilities = <ExerciseCapability>{
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.listening,
      if (_kind == LearningItemKind.sentence && sentenceTokens.length >= 2)
        ExerciseCapability.cloze,
      if (_kind == LearningItemKind.sentence && sentenceTokens.length >= 2)
        ExerciseCapability.sentenceOrder,
    };
    return LearningItem(
      id:
          'user-${subject.contentLanguage.code}-'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}',
      kind: _kind,
      learningLanguage: subject.contentLanguage,
      subjectId: subject.id,
      text: text,
      translations: meanings.isEmpty ? const [''] : meanings,
      acceptedAnswers: meanings,
      readings: [
        for (final reading in _splitValues(_readingController.text))
          Reading(scheme: ReadingScheme.hangul, value: reading),
      ],
      sentenceTokens: sentenceTokens,
      example: _nullable(_exampleController.text),
      exampleTranslation: _nullable(_exampleMeaningController.text),
      partOfSpeech: _kind == LearningItemKind.word ? _partOfSpeech : null,
      tags: [if (_selectedGroup case final group?) learningGroupTag(group)],
      capabilities: capabilities,
      source: ContentSource.userCreated,
    );
  }

  Future<void> _createGroup() async {
    final name = _newGroupController.text.trim();
    if (name.isEmpty) return;
    setState(() => _creatingGroup = true);
    try {
      final group = await ref
          .read(appControllerProvider.notifier)
          .createLearningGroup(name: name);
      if (!mounted) return;
      setState(() {
        _selectedGroup = group.name;
        _newGroupController.clear();
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _creatingGroup = false);
    }
  }

  Future<void> _save(StudySubject subject, {required bool keepAdding}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(appControllerProvider.notifier)
          .saveQuickContent(_candidate(subject));
      if (!mounted) return;
      if (!keepAdding) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.pop(context, result);
        return;
      }
      final message = result.mergedWithExisting
          ? result.addedMeaningCount > 0
                ? '기존 표현에 새 뜻을 추가했습니다.'
                : '이미 같은 표현과 뜻이 있어 기존 자료를 유지했습니다.'
          : '저장했습니다. 같은 그룹에 계속 추가할 수 있어요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _suspendDraftRefresh = true;
      try {
        _textController.clear();
        _meaningController.clear();
        _readingController.clear();
        _exampleController.clear();
        _exampleMeaningController.clear();
      } finally {
        _suspendDraftRefresh = false;
      }
      setState(() => _cleanDraftFingerprint = _draftFingerprint());
      FocusScope.of(context).requestFocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _tokenize(String value, LanguageTag language) {
    if (LanguageProfile.of(language).usesSpaces) {
      return value
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList(growable: false);
    }
    return value.runes.map(String.fromCharCode).toList(growable: false);
  }

  List<String> _splitValues(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList(growable: false);

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice({required this.item, required this.newMeanings});

  final LearningItem item;
  final List<String> newMeanings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final existing = item.translations
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final added = newMeanings
        .where((value) => !existing.contains(value.trim().toLowerCase()))
        .length;
    return Container(
      key: const Key('quick-content-duplicate-notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tertiary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.merge_rounded, color: colors.tertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              added > 0
                  ? '같은 표현이 있습니다. 저장하면 기존 자료에 새 뜻 $added개만 합칩니다.'
                  : '같은 표현과 뜻이 이미 있습니다. 중복 자료는 만들지 않습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
