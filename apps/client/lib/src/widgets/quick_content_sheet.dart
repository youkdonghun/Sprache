import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../domain/content_validation.dart';
import '../domain/korean_pronunciation.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/quick_content_draft.dart';
import '../domain/quick_content_input.dart';
import '../domain/quick_content_preferences.dart';
import '../domain/sentence_tokens.dart';
import '../domain/study_subject.dart';
import '../import/bulk_paste_parser.dart';
import '../state/app_state.dart';
import '../state/navigation_guard_state.dart';
import 'delimited_chip_input.dart';
import 'sentence_token_editor.dart';

class QuickContentPrefill {
  const QuickContentPrefill({
    this.text = '',
    this.meaning = '',
    this.example = '',
    this.exampleMeaning = '',
  });

  final String text;
  final String meaning;
  final String example;
  final String exampleMeaning;
}

Future<QuickContentSaveResult?> showQuickContentSheet({
  required BuildContext context,
  LearningItemKind initialKind = LearningItemKind.word,
  QuickContentPrefill? prefill,
  String initialText = '',
  String initialMeaning = '',
  String initialExample = '',
  String initialExampleMeaning = '',
}) {
  final effectivePrefill =
      prefill ??
      ((initialText.isEmpty &&
              initialMeaning.isEmpty &&
              initialExample.isEmpty &&
              initialExampleMeaning.isEmpty)
          ? null
          : QuickContentPrefill(
              text: initialText,
              meaning: initialMeaning,
              example: initialExample,
              exampleMeaning: initialExampleMeaning,
            ));
  return showModalBottomSheet<QuickContentSaveResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        _QuickContentSheet(initialKind: initialKind, prefill: effectivePrefill),
  );
}

class _QuickContentSheet extends ConsumerStatefulWidget {
  const _QuickContentSheet({required this.initialKind, this.prefill});

  final LearningItemKind initialKind;
  final QuickContentPrefill? prefill;

  @override
  ConsumerState<_QuickContentSheet> createState() => _QuickContentSheetState();
}

class _QuickContentSheetState extends ConsumerState<_QuickContentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _meaningController = TextEditingController();
  final _acceptedController = TextEditingController();
  final _readingController = TextEditingController();
  final _nativeReadingController = TextEditingController();
  final _romajiController = TextEditingController();
  final _exampleController = TextEditingController();
  final _exampleMeaningController = TextEditingController();
  final _tagsController = TextEditingController();
  final _groupSearchController = TextEditingController();
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
  var _draftReady = false;
  var _favorite = false;
  var _priority = 0;
  var _saveDuplicateSeparately = false;
  var _sentenceTokens = <String>[];
  Timer? _draftTimer;
  QuickContentDraft? _recoverableDraft;
  QuickContentLocalPreferences _quickPreferences =
      const QuickContentLocalPreferences();
  String? _duplicateDecisionKey;
  String? _selectedGroup;

  List<TextEditingController> get _draftControllers => [
    _textController,
    _meaningController,
    _acceptedController,
    _readingController,
    _nativeReadingController,
    _romajiController,
    _exampleController,
    _exampleMeaningController,
    _tagsController,
    _groupSearchController,
    _newGroupController,
  ];

  bool get _hasUnsavedChanges =>
      !_allowPop && _draftFingerprint() != _cleanDraftFingerprint;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _cleanDraftFingerprint = _draftFingerprint();
    if (widget.prefill case final prefill?) {
      _textController.text = prefill.text;
      _meaningController.text = prefill.meaning;
      _exampleController.text = prefill.example;
      _exampleMeaningController.text = prefill.exampleMeaning;
    }
    for (final controller in _draftControllers) {
      controller.addListener(_refreshDraftState);
    }
    _navigationGuard = ref.read(navigationGuardProvider)
      ..register(this, _confirmDiscardForNavigation);
    unawaited(_loadDraft());
  }

  @override
  void dispose() {
    _navigationGuard.unregister(this);
    _draftTimer?.cancel();
    for (final controller in _draftControllers) {
      controller
        ..removeListener(_refreshDraftState)
        ..dispose();
    }
    super.dispose();
  }

  void _refreshDraftState() {
    if (mounted && !_suspendDraftRefresh) {
      setState(() {});
      _scheduleDraftSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final subject = controller.activeSubject;
    final groupQuery = _groupSearchController.text.trim().toLowerCase();
    final recentGroup =
        _quickPreferences.recentGroupBySubject[subject.id]?.name;
    final groupDefinitions =
        controller.availableLearningGroupDefinitions
            .where(
              (group) =>
                  groupQuery.isEmpty ||
                  group.name.toLowerCase().contains(groupQuery),
            )
            .toList(growable: true)
          ..sort((left, right) {
            int rank(LearningGroupDefinition group) {
              if (group.name == _selectedGroup) return 0;
              if (group.name == recentGroup) return 1;
              if (group.pinned) return 2;
              return 3;
            }

            final byRank = rank(left).compareTo(rank(right));
            return byRank != 0
                ? byRank
                : right.updatedAt.compareTo(left.updatedAt);
          });
    final duplicate = _textController.text.trim().isEmpty
        ? null
        : controller.findContentIdentityMatch(_candidate(subject));
    final duplicateKey = duplicate == null
        ? null
        : const LearningContentValidator().identityKey(_candidate(subject));
    final normalization = QuickContentNormalizationPreview.inspect(
      text: _textController.text,
      meanings: _splitValues(_meaningController.text),
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 560;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _save(subject, keepAdding: false),
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
          shift: true,
        ): () =>
            _save(subject, keepAdding: true),
        const SingleActivator(LogicalKeyboardKey.escape): _requestClose,
      },
      child: PopScope<QuickContentSaveResult>(
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
                        key: const Key('quick-content-clipboard'),
                        onPressed: _saving
                            ? null
                            : () => _importClipboard(subject),
                        icon: const Icon(Icons.content_paste_go_rounded),
                        tooltip: '클립보드에서 함께 가져오기',
                      ),
                      IconButton(
                        key: const Key('quick-content-swap'),
                        onPressed: _saving ? null : _swapTermAndMeaning,
                        icon: const Icon(Icons.swap_vert_rounded),
                        tooltip: '표현과 뜻 바꾸기',
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
                          if (_recoverableDraft case final draft?) ...[
                            Card(
                              key: const Key('quick-content-draft-recovery'),
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.restore_rounded),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${_draftAgeLabel(draft.updatedAt)} '
                                            '작성하던 초안이 있습니다.',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        TextButton(
                                          key: const Key(
                                            'quick-content-draft-discard',
                                          ),
                                          onPressed: _discardRecoveredDraft,
                                          child: const Text('버리기'),
                                        ),
                                        FilledButton.tonal(
                                          key: const Key(
                                            'quick-content-draft-restore',
                                          ),
                                          onPressed: _restoreDraft,
                                          child: const Text('복원'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
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
                                label: Text(
                                  subject.isLanguage ? '문장' : '사실·문장',
                                ),
                              ),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (value) {
                              setState(() => _kind = value.first);
                              _scheduleDraftSave();
                            },
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
                          DelimitedChipInput(
                            controller: _meaningController,
                            fieldKey: const Key('quick-content-meaning'),
                            labelText: '한국어 뜻',
                            hintText: '예: 달성하다, 이루다',
                            required: true,
                            onSubmitted: (_) =>
                                _save(subject, keepAdding: false),
                          ),
                          if (normalization.hasChanges) ...[
                            const SizedBox(height: 10),
                            _NormalizationNotice(
                              preview: normalization,
                              onApply: _applyNormalization,
                            ),
                          ],
                          if (duplicate != null) ...[
                            const SizedBox(height: 10),
                            _DuplicateNotice(
                              item: duplicate,
                              newMeanings: _splitValues(
                                _meaningController.text,
                              ),
                              mergeSelected:
                                  _duplicateDecisionKey == duplicateKey &&
                                  !_saveDuplicateSeparately,
                              separateSelected:
                                  _duplicateDecisionKey == duplicateKey &&
                                  _saveDuplicateSeparately,
                              onMerge: () => setState(() {
                                _duplicateDecisionKey = duplicateKey;
                                _saveDuplicateSeparately = false;
                              }),
                              onOpen: () => _openExistingItem(duplicate),
                              onSeparate: () => setState(() {
                                _duplicateDecisionKey = duplicateKey;
                                _saveDuplicateSeparately = true;
                              }),
                            ),
                          ],
                          if (_kind == LearningItemKind.sentence) ...[
                            const SizedBox(height: 16),
                            SentenceTokenEditor(
                              sentenceText: _textController.text,
                              language: subject.contentLanguage,
                              tokens: _sentenceTokens,
                              onChanged: (tokens) {
                                setState(() => _sentenceTokens = tokens);
                                _scheduleDraftSave();
                              },
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
                          if (controller
                                      .availableLearningGroupDefinitions
                                      .length >=
                                  4 ||
                              groupQuery.isNotEmpty) ...[
                            TextField(
                              key: const Key('quick-content-group-search'),
                              controller: _groupSearchController,
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(Icons.search_rounded),
                                labelText: '그룹 검색',
                                hintText: '이름으로 그룹 찾기',
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  key: const Key('quick-content-no-group'),
                                  label: const Text('나중에 정리'),
                                  selected: _selectedGroup == null,
                                  onSelected: (_) {
                                    setState(() => _selectedGroup = null);
                                    _scheduleDraftSave();
                                  },
                                ),
                                for (final definition in groupDefinitions) ...[
                                  const SizedBox(width: 7),
                                  ChoiceChip(
                                    key: Key(
                                      'quick-content-group-${definition.name}',
                                    ),
                                    avatar: definition.pinned
                                        ? const Icon(
                                            Icons.push_pin_rounded,
                                            size: 16,
                                          )
                                        : definition.name == recentGroup
                                        ? const Icon(
                                            Icons.history_rounded,
                                            size: 16,
                                          )
                                        : null,
                                    label: Text(definition.name),
                                    selected: _selectedGroup == definition.name,
                                    onSelected: (_) {
                                      setState(
                                        () => _selectedGroup = definition.name,
                                      );
                                      _scheduleDraftSave();
                                      unawaited(
                                        _rememberGroup(
                                          subject.id,
                                          definition.name,
                                        ),
                                      );
                                    },
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
                              DelimitedChipInput(
                                controller: _acceptedController,
                                fieldKey: const Key(
                                  'quick-content-accepted-answers',
                                ),
                                labelText: '추가 정답 (선택)',
                                hintText: '뜻 외에 정답으로 인정할 표현',
                              ),
                              if (subject.contentLanguage ==
                                  LanguageTag.japanese) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key(
                                    'quick-content-native-reading',
                                  ),
                                  controller: _nativeReadingController,
                                  decoration: const InputDecoration(
                                    labelText: '가나 읽기 (선택)',
                                    hintText: '예: みず',
                                  ),
                                  validator: (value) => _readingInputError(
                                    value,
                                    ReadingScheme.kana,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('quick-content-romaji'),
                                  controller: _romajiController,
                                  decoration: const InputDecoration(
                                    labelText: '로마자 (선택)',
                                    hintText: '예: mizu',
                                  ),
                                  validator: (value) => _readingInputError(
                                    value,
                                    ReadingScheme.romaji,
                                  ),
                                ),
                              ],
                              if (subject.contentLanguage ==
                                  LanguageTag.simplifiedChinese) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key(
                                    'quick-content-native-reading',
                                  ),
                                  controller: _nativeReadingController,
                                  decoration: const InputDecoration(
                                    labelText: '병음 (선택)',
                                    hintText: '예: nǐ hǎo',
                                  ),
                                  validator: (value) => _readingInputError(
                                    value,
                                    ReadingScheme.pinyin,
                                  ),
                                ),
                              ],
                              if (subject.contentLanguage !=
                                  LanguageTag.korean) ...[
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        key: const Key('quick-content-reading'),
                                        controller: _readingController,
                                        decoration: InputDecoration(
                                          labelText: '한국어 발음 보조 (선택)',
                                          hintText: _koreanPronunciationHint(
                                            subject.contentLanguage,
                                          ),
                                        ),
                                        validator: (value) =>
                                            _readingInputError(
                                              value,
                                              ReadingScheme.hangul,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      key: const Key(
                                        'quick-content-suggest-pronunciation',
                                      ),
                                      onPressed: () => _suggestPronunciation(
                                        subject.contentLanguage,
                                      ),
                                      icon: const Icon(
                                        Icons.auto_fix_high_rounded,
                                      ),
                                      tooltip: '오프라인 발음 보조 제안',
                                    ),
                                  ],
                                ),
                              ],
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
                                  key: const Key(
                                    'quick-content-part-of-speech',
                                  ),
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
                                      _scheduleDraftSave();
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),
                              DelimitedChipInput(
                                controller: _tagsController,
                                fieldKey: const Key('quick-content-tags'),
                                labelText: '태그 (선택)',
                                hintText: '예: 여행, 시험, 자주 틀림',
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                key: const Key('quick-content-favorite'),
                                contentPadding: EdgeInsets.zero,
                                value: _favorite,
                                title: const Text('즐겨찾기에 추가'),
                                subtitle: const Text(
                                  '저장 직후 즐겨찾기 학습에서 볼 수 있어요.',
                                ),
                                onChanged: (value) {
                                  setState(() => _favorite = value);
                                  _scheduleDraftSave();
                                },
                              ),
                              Text('학습 우선순위 $_priority / 5'),
                              Slider(
                                key: const Key('quick-content-priority'),
                                value: _priority.toDouble(),
                                min: 0,
                                max: 5,
                                divisions: 5,
                                label: '$_priority',
                                onChanged: (value) {
                                  setState(() => _priority = value.round());
                                  _scheduleDraftSave();
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('quick-content-save-and-study'),
                    onPressed: _saving
                        ? null
                        : () =>
                              _save(subject, keepAdding: false, studyNow: true),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('저장하고 이 자료 학습하기'),
                  ),
                  const SizedBox(height: 8),
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
      ),
    );
  }

  String _draftFingerprint() => <Object?>[
    _kind.name,
    _partOfSpeech.name,
    _selectedGroup,
    _favorite,
    _priority,
    _sentenceTokens.join('\u001e'),
    for (final controller in _draftControllers) controller.text.trim(),
  ].join('\u001f');

  Future<void> _loadDraft() async {
    final store = ref.read(studyStoreProvider);
    final results = await Future.wait<Object?>([
      store.loadQuickContentDraft(),
      store.loadQuickContentLocalPreferences(),
    ]);
    final draft = results[0] as QuickContentDraft?;
    final preferences = results[1] as QuickContentLocalPreferences;
    if (!mounted) return;
    final controller = ref.read(appControllerProvider.notifier);
    final subjectId = controller.activeSubject.id;
    final recent = preferences.recentGroupBySubject[subjectId];
    final available = controller.availableLearningGroups.toSet();
    setState(() {
      _draftReady = true;
      _quickPreferences = preferences;
      if (_selectedGroup == null &&
          recent != null &&
          available.contains(recent.name)) {
        _selectedGroup = recent.name;
      }
      if (draft != null && draft.subjectId == subjectId && draft.hasContent) {
        _recoverableDraft = draft;
      }
      if (_recoverableDraft == null && widget.prefill == null) {
        _cleanDraftFingerprint = _draftFingerprint();
      }
    });
  }

  Future<void> _rememberGroup(String subjectId, String groupName) async {
    final next = _quickPreferences.rememberGroup(
      subjectId: subjectId,
      name: groupName,
    );
    _quickPreferences = next;
    await ref.read(studyStoreProvider).saveQuickContentLocalPreferences(next);
  }

  void _scheduleDraftSave() {
    if (!_draftReady || _recoverableDraft != null || _allowPop) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _allowPop) return;
      final draft = _currentDraft();
      if (draft.hasContent) {
        unawaited(ref.read(studyStoreProvider).saveQuickContentDraft(draft));
      } else {
        unawaited(ref.read(studyStoreProvider).clearQuickContentDraft());
      }
    });
  }

  QuickContentDraft _currentDraft() {
    final subject = ref.read(appControllerProvider.notifier).activeSubject;
    return QuickContentDraft(
      subjectId: subject.id,
      kind: _kind,
      text: _textController.text,
      meanings: _splitValues(_meaningController.text),
      acceptedAnswers: _splitValues(_acceptedController.text),
      readings: {
        ReadingScheme.hangul: _readingController.text,
        ReadingScheme.kana: _nativeReadingController.text,
        ReadingScheme.romaji: _romajiController.text,
        ReadingScheme.pinyin: _nativeReadingController.text,
      },
      sentenceTokens: List.unmodifiable(_sentenceTokens),
      example: _exampleController.text,
      exampleMeaning: _exampleMeaningController.text,
      partOfSpeech: _partOfSpeech,
      group: _selectedGroup,
      tags: _splitValues(_tagsController.text),
      favorite: _favorite,
      priority: _priority,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  void _restoreDraft() {
    final draft = _recoverableDraft;
    if (draft == null) return;
    _suspendDraftRefresh = true;
    try {
      _kind = draft.kind;
      _partOfSpeech = draft.partOfSpeech;
      _selectedGroup = draft.group;
      _favorite = draft.favorite;
      _priority = draft.priority;
      _sentenceTokens = [...draft.sentenceTokens];
      _textController.text = draft.text;
      _meaningController.text = draft.meanings.join(', ');
      _acceptedController.text = draft.acceptedAnswers.join(', ');
      _readingController.text = draft.readings[ReadingScheme.hangul] ?? '';
      final subject = ref.read(appControllerProvider.notifier).activeSubject;
      _nativeReadingController.text =
          subject.contentLanguage == LanguageTag.simplifiedChinese
          ? draft.readings[ReadingScheme.pinyin] ?? ''
          : draft.readings[ReadingScheme.kana] ?? '';
      _romajiController.text = draft.readings[ReadingScheme.romaji] ?? '';
      _exampleController.text = draft.example;
      _exampleMeaningController.text = draft.exampleMeaning;
      _tagsController.text = draft.tags.join(', ');
      _recoverableDraft = null;
    } finally {
      _suspendDraftRefresh = false;
    }
    setState(() {});
  }

  Future<void> _discardRecoveredDraft() async {
    await ref.read(studyStoreProvider).clearQuickContentDraft();
    if (mounted) setState(() => _recoverableDraft = null);
  }

  String _draftAgeLabel(DateTime updatedAt) {
    final elapsed = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (elapsed.inMinutes < 1) return '방금';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
    if (elapsed.inDays < 1) return '${elapsed.inHours}시간 전';
    return '${elapsed.inDays}일 전';
  }

  Future<void> _importClipboard(StudySubject subject) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      _showMessage('클립보드에 텍스트가 없습니다.');
      return;
    }
    BulkPasteResult parsed;
    try {
      parsed = const BulkPasteParser().parse(text);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }
    if (!parsed.canImport) {
      await _showClipboardIssues(parsed);
      return;
    }
    if (parsed.entries.length == 1) {
      final entry = parsed.entries.single;
      _suspendDraftRefresh = true;
      try {
        _textController.text = entry.term;
        _meaningController.text = entry.meaning;
        _acceptedController.clear();
        _readingController.clear();
        _nativeReadingController.clear();
        _romajiController.clear();
        _exampleController.clear();
        _exampleMeaningController.clear();
        _sentenceTokens = <String>[];
      } finally {
        _suspendDraftRefresh = false;
      }
      setState(() {});
      _scheduleDraftSave();
      if (parsed.issues.isNotEmpty) {
        _showMessage('${parsed.issues.length}개 행은 확인이 필요해 제외했습니다.');
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ClipboardPairReviewDialog(result: parsed),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final saved = <QuickContentSaveResult>[];
    try {
      for (final entry in parsed.entries) {
        var result = await ref
            .read(appControllerProvider.notifier)
            .saveQuickContent(_candidateForPair(subject, entry));
        if (_favorite &&
            !ref
                .read(appControllerProvider)
                .preferences
                .isFavorite(result.item.id)) {
          ref
              .read(appControllerProvider.notifier)
              .toggleFavorite(result.item.id);
          result = result.copyWith(favoriteAdded: true);
        }
        saved.add(result);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${saved.length}개를 저장했습니다. '
            '${parsed.issues.length}개 행은 제외했습니다.',
          ),
          action: SnackBarAction(
            label: '모두 취소',
            onPressed: () => unawaited(_undoBatch(saved).then((_) {})),
          ),
        ),
      );
    } catch (error) {
      final rolledBack = await _undoBatch(saved, announce: false);
      if (mounted) {
        _showMessage(
          '저장이 중단돼 성공했던 $rolledBack개를 자동으로 '
          '되돌렸습니다. 입력을 확인해 다시 시도해 주세요. $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  LearningItem _candidateForPair(StudySubject subject, BulkPasteEntry entry) {
    final capabilities = <ExerciseCapability>{
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.listening,
    };
    return LearningItem(
      id:
          'user-${subject.contentLanguage.code}-'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}-${entry.line}',
      kind: _kind,
      learningLanguage: subject.contentLanguage,
      subjectId: subject.id,
      text: entry.term,
      translations: [entry.meaning],
      acceptedAnswers: [entry.meaning],
      sentenceTokens: const [],
      partOfSpeech: _kind == LearningItemKind.word ? _partOfSpeech : null,
      tags: [
        ..._splitValues(_tagsController.text),
        if (_selectedGroup case final group?) learningGroupTag(group),
      ],
      capabilities: capabilities,
      priority: _priority,
      source: ContentSource.userCreated,
    );
  }

  Future<void> _showClipboardIssues(BulkPasteResult result) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('가져올 쌍을 찾지 못했습니다'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('단어와 뜻을 탭·쉼표로 나누거나 두 줄씩 입력해 주세요.'),
            for (final issue in result.issues.take(8))
              ListTile(
                dense: true,
                title: Text(issue.message),
                subtitle: issue.source.isEmpty ? null : Text(issue.source),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  void _swapTermAndMeaning() {
    final text = _textController.text.trim();
    final meanings = _splitValues(_meaningController.text);
    if (text.isEmpty || meanings.isEmpty) {
      _showMessage('표현과 뜻을 먼저 입력해 주세요.');
      return;
    }
    _suspendDraftRefresh = true;
    try {
      final example = _exampleController.text;
      _textController.text = meanings.first;
      _meaningController.text = [text, ...meanings.skip(1)].join(', ');
      _exampleController.text = _exampleMeaningController.text;
      _exampleMeaningController.text = example;
      _acceptedController.clear();
      _readingController.clear();
      _nativeReadingController.clear();
      _romajiController.clear();
      _sentenceTokens = <String>[];
    } finally {
      _suspendDraftRefresh = false;
    }
    setState(() {});
    _scheduleDraftSave();
    _showMessage('표현과 뜻을 바꿨습니다. 읽기·추가 정답·문장 토큰은 비웠습니다.');
  }

  void _applyNormalization() {
    final preview = QuickContentNormalizationPreview.inspect(
      text: _textController.text,
      meanings: _splitValues(_meaningController.text),
    );
    _suspendDraftRefresh = true;
    try {
      _textController.text = preview.normalizedText;
      _meaningController.text = preview.normalizedMeanings.join(', ');
      _acceptedController.text = _splitValues(
        _acceptedController.text,
      ).map(normalizeQuickContentValue).join(', ');
      if (preview.originalText != preview.normalizedText) {
        _sentenceTokens = <String>[];
      }
    } finally {
      _suspendDraftRefresh = false;
    }
    setState(() {});
    _scheduleDraftSave();
  }

  Future<void> _openExistingItem(LearningItem item) async {
    _draftTimer?.cancel();
    final draft = _currentDraft();
    if (draft.hasContent) {
      await ref.read(studyStoreProvider).saveQuickContentDraft(draft);
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop();
    unawaited(
      Future<void>.delayed(
        Duration.zero,
      ).then((_) => router.go('/library/edit/${item.id}')),
    );
  }

  String? _readingInputError(String? value, ReadingScheme scheme) {
    for (final reading in _splitValues(value ?? '')) {
      final issue = inspectReadingFormat(scheme, reading);
      if (issue != null) return issue.message;
    }
    return null;
  }

  void _suggestPronunciation(LanguageTag language) {
    final suggestion = tryDeriveKoreanPronunciation(
      language: language,
      text: _textController.text,
      reading: _nativeReadingController.text,
      romanization: _romajiController.text,
    );
    if (suggestion == null) {
      _showMessage('안전하게 만들 수 있는 발음 제안이 없습니다. 읽기를 먼저 입력해 보세요.');
      return;
    }
    _readingController.text = suggestion;
  }

  String _koreanPronunciationHint(LanguageTag language) => switch (language) {
    LanguageTag.english => '예: 헬로우',
    LanguageTag.japanese => '예: 미즈',
    LanguageTag.german => '예: 구텐 탁',
    LanguageTag.french => '예: 봉주르',
    LanguageTag.spanish => '예: 올라',
    LanguageTag.simplifiedChinese => '예: 니 하오',
    LanguageTag.korean => '',
  };

  Future<void> _undoSave(QuickContentSaveResult result) async {
    final status = await ref
        .read(appControllerProvider.notifier)
        .undoQuickContentSave(result.undoToken);
    if (!mounted) return;
    if (status == QuickContentUndoStatus.restored &&
        result.favoriteAdded &&
        ref
            .read(appControllerProvider)
            .preferences
            .isFavorite(result.item.id)) {
      ref.read(appControllerProvider.notifier).toggleFavorite(result.item.id);
    }
    _showMessage(switch (status) {
      QuickContentUndoStatus.restored => '마지막 저장을 되돌렸습니다.',
      QuickContentUndoStatus.conflict => '이후 수정된 자료라 안전하게 되돌리지 않았습니다.',
      QuickContentUndoStatus.alreadyUndone => '이미 되돌린 저장입니다.',
    });
  }

  Future<int> _undoBatch(
    List<QuickContentSaveResult> results, {
    bool announce = true,
  }) async {
    var restored = 0;
    for (final result in results.reversed) {
      final status = await ref
          .read(appControllerProvider.notifier)
          .undoQuickContentSave(result.undoToken);
      if (status == QuickContentUndoStatus.restored) {
        restored++;
        if (result.favoriteAdded &&
            ref
                .read(appControllerProvider)
                .preferences
                .isFavorite(result.item.id)) {
          ref
              .read(appControllerProvider.notifier)
              .toggleFavorite(result.item.id);
        }
      }
    }
    if (mounted && announce) _showMessage('$restored개 저장을 되돌렸습니다.');
    return restored;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestClose() async {
    if (!await _confirmDiscardForNavigation() || !mounted) return;
    if (_recoverableDraft == null) {
      _draftTimer?.cancel();
      await ref.read(studyStoreProvider).clearQuickContentDraft();
      if (!mounted) return;
    }
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
    _draftTimer?.cancel();
    await ref.read(studyStoreProvider).clearQuickContentDraft();
    if (!mounted) return false;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    return mounted;
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  LearningItem _candidate(StudySubject subject) {
    final text = _textController.text.trim();
    final meanings = _splitValues(_meaningController.text);
    final tokenInspection = const SentenceTokenValidator().inspect(
      sentence: text,
      tokens: _kind == LearningItemKind.sentence
          ? _sentenceTokens
          : const <String>[],
    );
    final sentenceTokens = _kind == LearningItemKind.sentence
        ? tokenInspection.tokens
        : const <String>[];
    final capabilities = <ExerciseCapability>{
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.listening,
      if (_kind == LearningItemKind.sentence &&
          tokenInspection.enablesSentenceExercises)
        ExerciseCapability.cloze,
      if (_kind == LearningItemKind.sentence &&
          tokenInspection.enablesSentenceExercises)
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
      acceptedAnswers: {
        ...meanings,
        ..._splitValues(_acceptedController.text),
      }.toList(growable: false),
      readings: _buildReadings(subject.contentLanguage),
      sentenceTokens: sentenceTokens,
      example: _nullable(_exampleController.text),
      exampleTranslation: _nullable(_exampleMeaningController.text),
      partOfSpeech: _kind == LearningItemKind.word ? _partOfSpeech : null,
      tags: [
        ..._splitValues(_tagsController.text),
        if (_selectedGroup case final group?) learningGroupTag(group),
      ],
      capabilities: capabilities,
      priority: _priority,
      source: ContentSource.userCreated,
    );
  }

  List<Reading> _buildReadings(LanguageTag language) {
    final readings = <Reading>[
      for (final value in _splitValues(_readingController.text))
        Reading(scheme: ReadingScheme.hangul, value: value),
    ];
    if (language == LanguageTag.japanese) {
      readings.addAll([
        for (final value in _splitValues(_nativeReadingController.text))
          Reading(scheme: ReadingScheme.kana, value: value),
        for (final value in _splitValues(_romajiController.text))
          Reading(scheme: ReadingScheme.romaji, value: value),
      ]);
    } else if (language == LanguageTag.simplifiedChinese) {
      readings.addAll([
        for (final value in _splitValues(_nativeReadingController.text))
          Reading(scheme: ReadingScheme.pinyin, value: value),
      ]);
    }
    return readings;
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
      await _rememberGroup(
        ref.read(appControllerProvider.notifier).activeSubject.id,
        group.name,
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _creatingGroup = false);
    }
  }

  Future<void> _save(
    StudySubject subject, {
    required bool keepAdding,
    bool studyNow = false,
  }) async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tokenInspection = const SentenceTokenValidator().inspect(
      sentence: _textController.text,
      tokens: _kind == LearningItemKind.sentence
          ? _sentenceTokens
          : const <String>[],
    );
    if (!tokenInspection.canSave) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tokenInspection.message!)));
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    final candidate = _candidate(subject);
    final duplicate = controller.findContentIdentityMatch(candidate);
    final duplicateKey = duplicate == null
        ? null
        : const LearningContentValidator().identityKey(candidate);
    if (duplicate != null && _duplicateDecisionKey != duplicateKey) {
      _showMessage('같은 표현이 있습니다. 뜻 병합이나 별도 저장을 먼저 고르세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      var result = await controller.saveQuickContent(
        candidate,
        allowDuplicate: duplicate != null && _saveDuplicateSeparately,
      );
      if (!mounted) return;
      if (_selectedGroup case final group?) {
        await _rememberGroup(subject.id, group);
        if (!mounted) return;
      }
      final wasFavorite = ref
          .read(appControllerProvider)
          .preferences
          .isFavorite(result.item.id);
      final favoriteAdded = _favorite && !wasFavorite;
      if (favoriteAdded) {
        ref.read(appControllerProvider.notifier).toggleFavorite(result.item.id);
      }
      result = result.copyWith(
        studyNow: studyNow,
        favoriteAdded: favoriteAdded,
      );
      _draftTimer?.cancel();
      await ref.read(studyStoreProvider).clearQuickContentDraft();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () => unawaited(_undoSave(result)),
          ),
        ),
      );
      _suspendDraftRefresh = true;
      try {
        _textController.clear();
        _meaningController.clear();
        _acceptedController.clear();
        _readingController.clear();
        _nativeReadingController.clear();
        _romajiController.clear();
        _exampleController.clear();
        _exampleMeaningController.clear();
        _tagsController.clear();
        _favorite = false;
        _priority = 0;
        _duplicateDecisionKey = null;
        _saveDuplicateSeparately = false;
        _sentenceTokens = <String>[];
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

  List<String> _splitValues(String value) => DelimitedChipInput.parse(value);

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice({
    required this.item,
    required this.newMeanings,
    required this.mergeSelected,
    required this.separateSelected,
    required this.onMerge,
    required this.onOpen,
    required this.onSeparate,
  });

  final LearningItem item;
  final List<String> newMeanings;
  final bool mergeSelected;
  final bool separateSelected;
  final VoidCallback onMerge;
  final VoidCallback onOpen;
  final VoidCallback onSeparate;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.merge_rounded, color: colors.tertiary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  added > 0
                      ? '같은 표현이 있습니다. 새 뜻 $added개를 합칠지, 열어볼지, 별도 저장할지 고르세요.'
                      : '같은 표현과 뜻이 이미 있습니다. 저장 방법을 직접 고르세요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            children: [
              ChoiceChip(
                key: const Key('quick-content-merge-existing'),
                selected: mergeSelected,
                onSelected: (_) => onMerge(),
                avatar: const Icon(Icons.merge_rounded, size: 16),
                label: const Text('뜻 병합'),
              ),
              ActionChip(
                key: const Key('quick-content-view-existing'),
                onPressed: onOpen,
                avatar: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('기존 항목 열기'),
              ),
              ChoiceChip(
                key: const Key('quick-content-save-separate'),
                selected: separateSelected,
                onSelected: (_) => onSeparate(),
                avatar: const Icon(Icons.call_split_rounded, size: 16),
                label: const Text('별도 저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NormalizationNotice extends StatelessWidget {
  const _NormalizationNotice({required this.preview, required this.onApply});

  final QuickContentNormalizationPreview preview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final before = [
      preview.originalText,
      ...preview.originalMeanings,
    ].join(' / ');
    final after = [
      preview.normalizedText,
      ...preview.normalizedMeanings,
    ].join(' / ');
    return Card(
      key: const Key('quick-content-normalization-preview'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.cleaning_services_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '저장 전 문자·공백 정리\n$before → $after',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onApply, child: const Text('적용')),
          ],
        ),
      ),
    );
  }
}

class _ClipboardPairReviewDialog extends StatelessWidget {
  const _ClipboardPairReviewDialog({required this.result});

  final BulkPasteResult result;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('quick-content-clipboard-review'),
    title: Text('${result.entryCount}개 쌍을 등록할까요?'),
    content: SizedBox(
      width: 560,
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${result.detectedFormat.label} 형식 · '
            '제외 ${result.issues.length}개',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: result.entries.length,
              itemBuilder: (context, index) {
                final entry = result.entries[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(entry.term),
                  subtitle: Text(entry.meaning),
                );
              },
            ),
          ),
          if (result.issues.isNotEmpty)
            Text(
              '문제가 있는 행은 저장하지 않습니다. 첫 문제: '
              '${result.issues.first.message}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('quick-content-clipboard-confirm'),
        onPressed: () => Navigator.pop(context, true),
        child: Text('${result.entryCount}개 저장'),
      ),
    ],
  );
}
