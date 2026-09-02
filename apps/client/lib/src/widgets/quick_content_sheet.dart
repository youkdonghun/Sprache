import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/study_store.dart';
import '../domain/content_validation.dart';
import '../domain/app_experience_preferences.dart';
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
import '../services/clipboard_read_session.dart';
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
  LearningItemKind? initialKind,
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

  final LearningItemKind? initialKind;
  final QuickContentPrefill? prefill;

  @override
  ConsumerState<_QuickContentSheet> createState() => _QuickContentSheetState();
}

class _QuickContentSheetState extends ConsumerState<_QuickContentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textFocusNode = FocusNode(debugLabel: 'quick content text');
  final _meaningFocusNode = FocusNode(debugLabel: 'quick content meaning');
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
  final _detailsTileController = ExpansibleController();
  final _clipboardSession = ClipboardReadSession();
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
  var _editedBeforeDraftLoad = false;
  var _favorite = false;
  var _priority = 0;
  var _saveDuplicateSeparately = false;
  var _detailsExpanded = false;
  var _showNewGroupFields = false;
  var _sentenceTokens = <String>[];
  var _basket = <_QuickBasketEntry>[];
  var _sessionUndo = <QuickContentSaveResult>[];
  Timer? _draftTimer;
  Timer? _suggestionTimer;
  var _pendingSuggestionText = '';
  var _settledSuggestionText = '';
  late String _lastObservedDraftFingerprint;
  late final StudyStore _studyStore;
  late String _draftSubjectId;
  QuickContentDraft? _pendingDraftSnapshot;
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
    _studyStore = ref.read(studyStoreProvider);
    _draftSubjectId = ref.read(appControllerProvider.notifier).activeSubject.id;
    final experience = ref.read(appControllerProvider).preferences.experience;
    _kind = widget.initialKind ?? _initialKind(experience.quickAddKind);
    _favorite = experience.quickAddFavoriteDefault;
    _priority = experience.quickAddPriorityDefault;
    _detailsExpanded = experience.quickAddOpenDetails;
    _cleanDraftFingerprint = _draftFingerprint();
    if (widget.prefill case final prefill?) {
      _textController.text = prefill.text;
      _meaningController.text = prefill.meaning;
      _exampleController.text = prefill.example;
      _exampleMeaningController.text = prefill.exampleMeaning;
    }
    _lastObservedDraftFingerprint = _draftFingerprint();
    _pendingSuggestionText = _textController.text.trim();
    if (_pendingSuggestionText.runes.length >= 2) {
      _suggestionTimer = Timer(
        const Duration(milliseconds: 220),
        _commitPendingSuggestionText,
      );
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
    _suggestionTimer?.cancel();
    final pendingDraft =
        _pendingDraftSnapshot ??
        (_draftFingerprint() == _cleanDraftFingerprint
            ? null
            : _currentDraft());
    if (pendingDraft != null &&
        _recoverableDraft == null &&
        !_allowPop &&
        !_clipboardSession.hasUnconfirmedContent) {
      // Register the final snapshot with the store before this state becomes
      // unreachable. Store-level write ordering makes a replacement sheet's
      // immediate load wait for this best-effort flush.
      unawaited(_persistDraftSnapshot(pendingDraft));
    }
    if (_clipboardSession.hasUnconfirmedContent) {
      _suspendDraftRefresh = true;
      for (final controller in _draftControllers) {
        controller.clear();
      }
      _clipboardSession.discard();
    }
    for (final controller in _draftControllers) {
      controller
        ..removeListener(_refreshDraftState)
        ..dispose();
    }
    _textFocusNode.dispose();
    _meaningFocusNode.dispose();
    _detailsTileController.dispose();
    super.dispose();
  }

  void _refreshDraftState() {
    if (!mounted || _suspendDraftRefresh) return;
    final fingerprint = _draftFingerprint();
    // Text controllers also notify when only their selection changes. Those
    // events do not need to rebuild this large sheet or rescan the catalog.
    if (fingerprint == _lastObservedDraftFingerprint) return;
    _lastObservedDraftFingerprint = fingerprint;
    if (!_draftReady && fingerprint != _cleanDraftFingerprint) {
      _editedBeforeDraftLoad = true;
    }
    _scheduleSuggestionRefresh();
    setState(() {});
    _scheduleDraftSave();
  }

  void _scheduleSuggestionRefresh() {
    final next = _textController.text.trim();
    if (next == _pendingSuggestionText) return;
    _pendingSuggestionText = next;
    _suggestionTimer?.cancel();
    if (next.runes.length < 2) {
      _settledSuggestionText = '';
      return;
    }
    _suggestionTimer = Timer(
      const Duration(milliseconds: 220),
      _commitPendingSuggestionText,
    );
  }

  void _commitPendingSuggestionText() {
    if (!mounted || _settledSuggestionText == _pendingSuggestionText) return;
    setState(() => _settledSuggestionText = _pendingSuggestionText);
  }

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(
      appControllerProvider.select((state) => state.preferences.experience),
    );
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
    final availableGroupNames = {
      for (final group in groupDefinitions) group.name,
    };
    final recentGroupAvailable =
        recentGroup != null && availableGroupNames.contains(recentGroup);
    final duplicateCandidate = _candidate(subject);
    final currentText = _textController.text.trim();
    final settledText = _settledSuggestionText;
    final suggestionsCurrent =
        settledText.runes.length >= 2 && settledText == currentText;
    final duplicate = !suggestionsCurrent
        ? null
        : controller.findContentIdentityMatch(duplicateCandidate);
    final duplicateKey = duplicate == null
        ? null
        : const LearningContentValidator().identityKey(duplicateCandidate);
    final normalization = QuickContentNormalizationPreview.inspect(
      text: _textController.text,
      meanings: _splitValues(_meaningController.text),
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 560;
    final keyboardFocusMode = compact && bottomInset > 80;
    final recoverableDraft = keyboardFocusMode ? null : _recoverableDraft;
    final dense = Theme.of(context).visualDensity.vertical < 0;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final compactActionBar =
        compact || (largeText && MediaQuery.sizeOf(context).width < 900);
    final compactLargeText = compactActionBar && largeText;
    final requiredCompleted = [
      _textController.text.trim(),
      _meaningController.text.trim(),
    ].where((value) => value.isNotEmpty).length;
    final recentTags =
        _quickPreferences.recentTagsBySubject[subject.id] ?? const <String>[];
    final suggestionText = settledText;
    final suggestionsEnabled =
        _kind == LearningItemKind.word && suggestionsCurrent;
    final similarItems = suggestionsEnabled
        ? controller.similarItemsForText(
            subjectId: subject.id,
            text: suggestionText,
          )
        : const <({LearningItem item, double score})>[];
    final exampleSuggestions = suggestionsEnabled
        ? controller.exampleSuggestionsForText(
            subjectId: subject.id,
            text: suggestionText,
          )
        : const <LearningItem>[];
    final selectedTags = _splitValues(_tagsController.text).toSet();
    final tagSuggestions = suggestionsEnabled
        ? controller.contentTagSuggestions(
            subjectId: subject.id,
            query: _tagSuggestionQuery(),
            excludedTags: selectedTags,
          )
        : const <String>[];
    final groupSuggestions = suggestionsEnabled
        ? controller.contentGroupSuggestions(
            subjectId: subject.id,
            text: suggestionText,
          )
        : const <String>[];
    final templates = _quickPreferences.orderedTemplates(subject.id);
    final detailFieldCount = <Object?>[
      if (_acceptedController.text.trim().isNotEmpty) true,
      if (_readingController.text.trim().isNotEmpty) true,
      if (_nativeReadingController.text.trim().isNotEmpty) true,
      if (_romajiController.text.trim().isNotEmpty) true,
      if (_exampleController.text.trim().isNotEmpty) true,
      if (_exampleMeaningController.text.trim().isNotEmpty) true,
      if (_tagsController.text.trim().isNotEmpty) true,
      if (_favorite) true,
      if (_priority > 0) true,
    ].length;
    final duplicateDefaultLabel = switch (experience.duplicateDefault) {
      AppDuplicateDefault.ask => '저장할 때 물어보기',
      AppDuplicateDefault.merge => '기본값 · 뜻 합치기',
      AppDuplicateDefault.separate => '기본값 · 따로 저장',
    };
    final textField = TextFormField(
      key: const Key('quick-content-text'),
      controller: _textController,
      focusNode: _textFocusNode,
      autofocus: true,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _meaningFocusNode.requestFocus(),
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
        suffixIcon: _textController.text.isEmpty
            ? null
            : ExcludeFocus(
                child: IconButton(
                  key: const Key('quick-content-clear-text'),
                  onPressed: _textController.clear,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '표현 지우기',
                ),
              ),
      ),
      validator: _required,
    );
    final meaningField = DelimitedChipInput(
      controller: _meaningController,
      focusNode: _meaningFocusNode,
      fieldKey: const Key('quick-content-meaning'),
      labelText: '한국어 뜻',
      hintText: '예: 달성하다, 이루다',
      required: true,
      helperText: null,
      suffixIcon: _meaningController.text.isEmpty
          ? null
          : ExcludeFocus(
              child: IconButton(
                key: const Key('quick-content-clear-meaning'),
                onPressed: _meaningController.clear,
                icon: const Icon(Icons.close_rounded),
                tooltip: '뜻 지우기',
              ),
            ),
      textInputAction: _detailsExpanded
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: (_) {
        if (_detailsExpanded) {
          FocusScope.of(context).nextFocus();
        } else {
          unawaited(
            _save(subject, keepAdding: experience.quickAddKeepAddingDefault),
          );
        }
      },
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _save(subject, keepAdding: experience.quickAddKeepAddingDefault),
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
          shift: true,
        ): () =>
            _save(subject, keepAdding: !experience.quickAddKeepAddingDefault),
        const SingleActivator(LogicalKeyboardKey.escape): _requestClose,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): () {
          FocusScope.of(context).previousFocus();
        },
      },
      child: PopScope<QuickContentSaveResult>(
        key: const Key('quick-content-sheet'),
        canPop: _allowPop || !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_requestClose());
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            dense ? 12 : 18,
            0,
            dense ? 12 : 18,
            bottomInset + (dense ? 10 : 16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dense ? 680 : 720,
              maxHeight: dense ? 720 : 760,
            ),
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
                              '빠른 추가',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (!dense && !keyboardFocusMode) ...[
                              const SizedBox(height: 2),
                              Text(
                                '표현과 뜻만 쓰면 바로 저장할 수 있어요.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!keyboardFocusMode) ...[
                        IconButton(
                          key: const Key('quick-content-clipboard'),
                          onPressed: _saving || _clipboardSession.hasRead
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
                      ],
                      IconButton(
                        key: const Key('quick-content-close'),
                        onPressed: _saving ? null : _requestClose,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '닫기',
                      ),
                    ],
                  ),
                  SizedBox(height: dense ? 9 : 14),
                  if (recoverableDraft case final draft?) ...[
                    Card(
                      key: const Key('quick-content-draft-recovery'),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.restore_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${_draftAgeLabel(draft.updatedAt)} '
                                    '작성하던 내용이 남아 있어요.',
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
                                  key: const Key('quick-content-draft-discard'),
                                  onPressed: _discardRecoveredDraft,
                                  child: const Text('버리기'),
                                ),
                                FilledButton.tonal(
                                  key: const Key('quick-content-draft-restore'),
                                  onPressed: _restoreDraft,
                                  child: const Text('이어쓰기'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('quick-content-scroll'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!keyboardFocusMode) ...[
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
                            SizedBox(height: dense ? 8 : 12),
                          ] else ...[
                            _QuickInputFocusStatus(
                              kind: _kind,
                              basketCount: _basket.length,
                            ),
                            const SizedBox(height: 8),
                          ],
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 560) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    textField,
                                    SizedBox(height: dense ? 8 : 12),
                                    meaningField,
                                  ],
                                );
                              }
                              return Row(
                                key: const Key(
                                  'quick-content-core-fields-inline',
                                ),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: textField),
                                  const SizedBox(width: 10),
                                  Expanded(child: meaningField),
                                ],
                              );
                            },
                          ),
                          if (!keyboardFocusMode) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              key: const Key('quick-content-required-progress'),
                              label: '필수 입력 $requiredCompleted개 중 2개 완료',
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: requiredCompleted == 2
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        requiredCompleted == 2
                                            ? Icons.check_circle_rounded
                                            : Icons.pending_outlined,
                                        size: 16,
                                        color: requiredCompleted == 2
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        requiredCompleted == 2
                                            ? compactLargeText
                                                  ? '완료'
                                                  : '필수 입력 완료'
                                            : compactLargeText
                                            ? '$requiredCompleted / 2'
                                            : '필수 입력 $requiredCompleted / 2',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 5),
                              Text(
                                'Enter 다음 입력 · Shift+Enter 이전 입력 · Ctrl+Enter 저장',
                                key: const Key('quick-content-keyboard-hint'),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
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
                                incoming: duplicateCandidate,
                                defaultLabel: duplicateDefaultLabel,
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
                            if (similarItems.isNotEmpty ||
                                exampleSuggestions.isNotEmpty ||
                                tagSuggestions.isNotEmpty ||
                                groupSuggestions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _ContentSuggestions(
                                similarItems: similarItems,
                                examples: exampleSuggestions,
                                tags: tagSuggestions,
                                groups: groupSuggestions,
                                onOpenSimilar: _openExistingItem,
                                onUseExample: _applyExampleSuggestion,
                                onUseTag: _appendRecentTag,
                                onUseGroup: (group) {
                                  setState(() => _selectedGroup = group);
                                  _scheduleDraftSave();
                                  unawaited(_rememberGroup(subject.id, group));
                                },
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
                            SizedBox(height: dense ? 8 : 12),
                            ExpansionTile(
                              key: const Key('quick-content-group-options'),
                              initiallyExpanded: _selectedGroup != null,
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.folder_copy_outlined),
                              title: const Text('학습 그룹'),
                              subtitle: Text(
                                _selectedGroup == null
                                    ? '선택하지 않음'
                                    : '$_selectedGroup에 바로 저장',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: _selectedGroup != null
                                  ? IconButton(
                                      key: const Key(
                                        'quick-content-clear-group',
                                      ),
                                      onPressed: () {
                                        setState(() => _selectedGroup = null);
                                        _scheduleDraftSave();
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: '그룹 선택 해제',
                                    )
                                  : recentGroupAvailable
                                  ? TextButton.icon(
                                      key: const Key(
                                        'quick-content-select-recent-group',
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _selectedGroup = recentGroup,
                                        );
                                        _scheduleDraftSave();
                                      },
                                      icon: const Icon(
                                        Icons.history_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        recentGroup,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '그룹을 고르면 저장할 때 바로 정리돼요.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (controller
                                            .availableLearningGroupDefinitions
                                            .length >=
                                        4 ||
                                    groupQuery.isNotEmpty) ...[
                                  TextField(
                                    key: const Key(
                                      'quick-content-group-search',
                                    ),
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
                                        key: const Key(
                                          'quick-content-no-group',
                                        ),
                                        label: const Text('그룹 없이 저장'),
                                        selected: _selectedGroup == null,
                                        onSelected: (_) {
                                          setState(() => _selectedGroup = null);
                                          _scheduleDraftSave();
                                        },
                                      ),
                                      for (final definition
                                          in groupDefinitions) ...[
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
                                          selected:
                                              _selectedGroup == definition.name,
                                          onSelected: (_) {
                                            setState(
                                              () => _selectedGroup =
                                                  definition.name,
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
                                const SizedBox(height: 8),
                                if (!_showNewGroupFields)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      key: const Key(
                                        'quick-content-show-new-group',
                                      ),
                                      onPressed: () => setState(
                                        () => _showNewGroupFields = true,
                                      ),
                                      icon: const Icon(
                                        Icons.create_new_folder_outlined,
                                      ),
                                      label: const Text('새 그룹 만들기'),
                                    ),
                                  )
                                else
                                  Row(
                                    key: const Key(
                                      'quick-content-new-group-fields',
                                    ),
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          key: const Key(
                                            'quick-content-new-group',
                                          ),
                                          controller: _newGroupController,
                                          maxLength: 40,
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) => _createGroup(),
                                          decoration: InputDecoration(
                                            labelText:
                                                groupDefinitions.isEmpty &&
                                                    groupQuery.isNotEmpty
                                                ? '“$groupQuery” 그룹 만들기'
                                                : '새 그룹 이름',
                                            counterText: '',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        key: const Key(
                                          'quick-content-create-group',
                                        ),
                                        onPressed: _creatingGroup
                                            ? null
                                            : () {
                                                if (_newGroupController.text
                                                        .trim()
                                                        .isEmpty &&
                                                    groupQuery.isNotEmpty) {
                                                  _newGroupController.text =
                                                      groupQuery;
                                                }
                                                _createGroup();
                                              },
                                        icon: _creatingGroup
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons
                                                    .create_new_folder_outlined,
                                              ),
                                        tooltip: '그룹 만들고 선택',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ExpansionTile(
                              key: const Key('quick-content-more'),
                              controller: _detailsTileController,
                              initiallyExpanded: _detailsExpanded,
                              onExpansionChanged: (value) =>
                                  setState(() => _detailsExpanded = value),
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: const Text('추가 정보 (선택)'),
                              subtitle: Text(
                                detailFieldCount == 0
                                    ? '예문·읽기·태그는 필요할 때만 입력하세요'
                                    : '$detailFieldCount개 항목 입력됨',
                              ),
                              children: [
                                const SizedBox(height: 6),
                                DelimitedChipInput(
                                  controller: _acceptedController,
                                  fieldKey: const Key(
                                    'quick-content-accepted-answers',
                                  ),
                                  labelText: '다른 정답도 허용 (선택)',
                                  hintText: '위의 뜻과 함께 정답으로 인정할 표현',
                                  helperText: null,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                ),
                                if (subject.contentLanguage ==
                                    LanguageTag.japanese) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    key: const Key(
                                      'quick-content-native-reading',
                                    ),
                                    controller: _nativeReadingController,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context).nextFocus(),
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
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context).nextFocus(),
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
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context).nextFocus(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          key: const Key(
                                            'quick-content-reading',
                                          ),
                                          controller: _readingController,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) =>
                                              FocusScope.of(
                                                context,
                                              ).nextFocus(),
                                          decoration: InputDecoration(
                                            labelText: '한글로 읽는 법 (선택)',
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
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final example = TextFormField(
                                      key: const Key('quick-content-example'),
                                      controller: _exampleController,
                                      maxLines: 2,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText: '예문 (선택)',
                                      ),
                                    );
                                    final meaning = TextFormField(
                                      key: const Key(
                                        'quick-content-example-meaning',
                                      ),
                                      controller: _exampleMeaningController,
                                      maxLines: 2,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText: '예문 뜻 (선택)',
                                      ),
                                    );
                                    if (constraints.maxWidth < 560) {
                                      return Column(
                                        children: [
                                          example,
                                          const SizedBox(height: 12),
                                          meaning,
                                        ],
                                      );
                                    }
                                    return Row(
                                      key: const Key(
                                        'quick-content-examples-inline',
                                      ),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: example),
                                        const SizedBox(width: 10),
                                        Expanded(child: meaning),
                                      ],
                                    );
                                  },
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
                                if (experience.quickAddRememberTags &&
                                    recentTags.isNotEmpty) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      key: const Key(
                                        'quick-content-recent-tags',
                                      ),
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final tag in recentTags)
                                          ActionChip(
                                            label: Text(tag),
                                            tooltip: '$tag 태그 추가',
                                            onPressed: () =>
                                                _appendRecentTag(tag),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                DelimitedChipInput(
                                  controller: _tagsController,
                                  fieldKey: const Key('quick-content-tags'),
                                  labelText: '태그 (선택)',
                                  hintText: '예: 여행, 시험, 자주 틀림',
                                  helperText: null,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => unawaited(
                                    _save(
                                      subject,
                                      keepAdding:
                                          experience.quickAddKeepAddingDefault,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final favorite = SwitchListTile.adaptive(
                                      key: const Key('quick-content-favorite'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      value: _favorite,
                                      title: const Text('즐겨찾기'),
                                      onChanged: (value) {
                                        setState(() => _favorite = value);
                                        _scheduleDraftSave();
                                      },
                                    );
                                    final priority = Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('우선순위 $_priority / 5'),
                                        Slider(
                                          key: const Key(
                                            'quick-content-priority',
                                          ),
                                          value: _priority.toDouble(),
                                          min: 0,
                                          max: 5,
                                          divisions: 5,
                                          label: '$_priority',
                                          onChanged: (value) {
                                            setState(
                                              () => _priority = value.round(),
                                            );
                                            _scheduleDraftSave();
                                          },
                                        ),
                                      ],
                                    );
                                    if (constraints.maxWidth < 520) {
                                      return Column(
                                        children: [favorite, priority],
                                      );
                                    }
                                    return Row(
                                      key: const Key(
                                        'quick-content-preferences-inline',
                                      ),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(child: favorite),
                                        const SizedBox(width: 12),
                                        Expanded(child: priority),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                            SizedBox(height: dense ? 8 : 12),
                            if (_draftReady)
                              _QuickRegistrationWorkbench(
                                templates: templates,
                                templateSort: _quickPreferences.templateSort,
                                basket: _basket,
                                recentSaves: _sessionUndo,
                                saving: _saving,
                                onCreateTemplate: () =>
                                    _createTemplate(subject),
                                onApplyTemplate: (template) =>
                                    _applyTemplate(subject, template),
                                onTemplateAction: (template, action) =>
                                    _handleTemplateAction(
                                      subject,
                                      template,
                                      action,
                                    ),
                                onSortChanged: _changeTemplateSort,
                                onRemoveBasket: _removeBasketEntry,
                                onApplyBatchOptions:
                                    _applyCurrentOptionsToBasket,
                                onSaveBasket: () => _saveBasket(subject),
                                onUndo: _undoRecentSave,
                              )
                            else
                              const LinearProgressIndicator(
                                key: Key('quick-content-tools-loading'),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (compactActionBar)
                    Row(
                      children: [
                        if (!keyboardFocusMode) ...[
                          IconButton.filledTonal(
                            key: const Key('quick-content-save-and-study'),
                            onPressed: _saving
                                ? null
                                : () => _save(
                                    subject,
                                    keepAdding: false,
                                    studyNow: true,
                                  ),
                            icon: const Icon(Icons.play_circle_outline_rounded),
                            tooltip: '저장하고 이 자료 학습하기',
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton.filledTonal(
                          key: const Key('quick-content-add-to-basket'),
                          onPressed: _saving
                              ? null
                              : () => _addToBasket(subject),
                          icon: const Icon(Icons.playlist_add_rounded),
                          tooltip: _basket.isEmpty
                              ? '저장 목록에 담기'
                              : '저장 목록에 담기 · ${_basket.length}',
                        ),
                        if (!keyboardFocusMode) ...[
                          const SizedBox(width: 4),
                          if (experience.quickAddKeepAddingDefault)
                            IconButton.filled(
                              key: const Key('quick-content-save-and-add'),
                              onPressed: _saving
                                  ? null
                                  : () => _save(subject, keepAdding: true),
                              icon: const Icon(Icons.add_rounded),
                              tooltip: '저장 후 계속 추가 · 기본',
                            )
                          else
                            IconButton(
                              key: const Key('quick-content-save-and-add'),
                              onPressed: _saving
                                  ? null
                                  : () => _save(subject, keepAdding: true),
                              icon: const Icon(Icons.add_rounded),
                              tooltip: '저장 후 계속 추가',
                            ),
                          const SizedBox(width: 4),
                        ],
                        if (compactLargeText)
                          IconButton(
                            key: const Key('quick-content-save'),
                            onPressed: _saving
                                ? null
                                : () => _save(subject, keepAdding: false),
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            tooltip: experience.quickAddKeepAddingDefault
                                ? '저장'
                                : '저장 · 기본',
                            style: experience.quickAddKeepAddingDefault
                                ? null
                                : IconButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                          )
                        else
                          Expanded(
                            child: experience.quickAddKeepAddingDefault
                                ? OutlinedButton(
                                    key: const Key('quick-content-save'),
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                              _save(subject, keepAdding: false),
                                    child: Text(_saving ? '저장 중…' : '저장'),
                                  )
                                : FilledButton(
                                    key: const Key('quick-content-save'),
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                              _save(subject, keepAdding: false),
                                    child: Text(_saving ? '저장 중…' : '저장 · 기본'),
                                  ),
                          ),
                      ],
                    )
                  else
                    Row(
                      key: const Key('quick-content-desktop-action-row'),
                      children: [
                        IconButton.filledTonal(
                          key: const Key('quick-content-save-and-study'),
                          onPressed: _saving
                              ? null
                              : () => _save(
                                  subject,
                                  keepAdding: false,
                                  studyNow: true,
                                ),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          tooltip: '저장하고 이 자료 학습하기',
                        ),
                        const SizedBox(width: 4),
                        Badge(
                          isLabelVisible: _basket.isNotEmpty,
                          label: Text('${_basket.length}'),
                          child: IconButton.filledTonal(
                            key: const Key('quick-content-add-to-basket'),
                            onPressed: _saving
                                ? null
                                : () => _addToBasket(subject),
                            icon: const Icon(Icons.playlist_add_rounded),
                            tooltip: '저장 목록에 담기',
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          key: const Key('quick-content-cancel'),
                          onPressed: _saving ? null : _requestClose,
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 6),
                        if (experience.quickAddKeepAddingDefault)
                          FilledButton.icon(
                            key: const Key('quick-content-save-and-add'),
                            onPressed: _saving
                                ? null
                                : () => _save(subject, keepAdding: true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('저장 후 계속 · 기본'),
                          )
                        else
                          OutlinedButton.icon(
                            key: const Key('quick-content-save-and-add'),
                            onPressed: _saving
                                ? null
                                : () => _save(subject, keepAdding: true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('저장 후 계속'),
                          ),
                        const SizedBox(width: 6),
                        if (experience.quickAddKeepAddingDefault)
                          OutlinedButton.icon(
                            key: const Key('quick-content-save'),
                            onPressed: _saving
                                ? null
                                : () => _save(subject, keepAdding: false),
                            icon: const Icon(Icons.save_rounded),
                            label: Text(_saving ? '저장 중…' : '저장'),
                          )
                        else
                          FilledButton.icon(
                            key: const Key('quick-content-save'),
                            onPressed: _saving
                                ? null
                                : () => _save(subject, keepAdding: false),
                            icon: const Icon(Icons.save_rounded),
                            label: Text(_saving ? '저장 중…' : '저장 · 기본'),
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
    for (final entry in _basket)
      <Object?>[
        entry.item.id,
        entry.item.text,
        entry.item.translations.join('\u001d'),
        entry.item.tags.join('\u001d'),
        entry.item.priority,
        entry.favorite,
      ].join('\u001c'),
  ].join('\u001f');

  Future<void> _loadDraft() async {
    final store = _studyStore;
    final controller = ref.read(appControllerProvider.notifier);
    final subjectId = controller.activeSubject.id;
    final results = await Future.wait<Object?>([
      store.loadQuickContentDraft(subjectId: subjectId),
      store.loadQuickContentLocalPreferences(),
    ]);
    final draft = results[0] as QuickContentDraft?;
    final preferences = results[1] as QuickContentLocalPreferences;
    if (!mounted) return;
    if (controller.activeSubject.id != subjectId) {
      unawaited(_loadDraft());
      return;
    }
    _draftSubjectId = subjectId;
    final recent = preferences.recentGroupBySubject[subjectId];
    final available = controller.availableLearningGroups.toSet();
    setState(() {
      _draftReady = true;
      _quickPreferences = preferences;
      if (!_editedBeforeDraftLoad &&
          _recoverableDraft == null &&
          widget.prefill == null &&
          widget.initialKind == null &&
          ref.read(appControllerProvider).preferences.experience.quickAddKind ==
              AppQuickAddKind.lastUsed) {
        _kind = preferences.lastKindBySubject[subjectId] ?? _kind;
      }
      if (_selectedGroup == null &&
          recent != null &&
          available.contains(recent.name)) {
        _selectedGroup = recent.name;
      }
      if (!_editedBeforeDraftLoad &&
          draft != null &&
          draft.subjectId == subjectId &&
          draft.hasContent) {
        _recoverableDraft = draft;
      }
      if (!_editedBeforeDraftLoad &&
          _recoverableDraft == null &&
          widget.prefill == null) {
        _cleanDraftFingerprint = _draftFingerprint();
      }
    });
    if (_editedBeforeDraftLoad) _scheduleDraftSave();
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
    if (!_draftReady ||
        _recoverableDraft != null ||
        _allowPop ||
        _clipboardSession.hasUnconfirmedContent) {
      return;
    }
    _draftTimer?.cancel();
    _pendingDraftSnapshot = _currentDraft();
    final delay = ref
        .read(appControllerProvider)
        .preferences
        .experience
        .quickAddDraftDelayMs;
    _draftTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _allowPop) return;
      unawaited(_persistCurrentDraftNow());
    });
  }

  QuickContentDraft _currentDraft() {
    return QuickContentDraft(
      subjectId: _draftSubjectId,
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
      basket: [
        for (final entry in _basket)
          QuickContentBasketDraftEntry(
            item: entry.item,
            favorite: entry.favorite,
          ),
      ],
    );
  }

  Future<void> _persistCurrentDraftNow() {
    _draftTimer?.cancel();
    final draft = _currentDraft();
    _pendingDraftSnapshot = draft;
    return _persistDraftSnapshot(draft);
  }

  Future<void> _persistDraftSnapshot(QuickContentDraft draft) {
    final write = () async {
      try {
        if (draft.hasContent) {
          await _studyStore.saveQuickContentDraft(draft);
        } else {
          await _studyStore.clearQuickContentDraft(subjectId: draft.subjectId);
        }
      } on Object {
        // Recovery storage is best-effort and never blocks content entry.
      }
    }();
    return write;
  }

  Future<void> _clearPersistedDraftNow() {
    _draftTimer?.cancel();
    final subjectId = _draftSubjectId;
    _pendingDraftSnapshot = null;
    final write = () async {
      try {
        await _studyStore.clearQuickContentDraft(subjectId: subjectId);
      } on Object {
        // Recovery cleanup must not change the result of a content action.
      }
    }();
    return write;
  }

  void _restoreDraft() {
    final draft = _recoverableDraft;
    if (draft == null) return;
    final appController = ref.read(appControllerProvider.notifier);
    final availableGroups = appController.availableLearningGroups;
    _suspendDraftRefresh = true;
    try {
      _kind = draft.kind;
      _partOfSpeech = draft.partOfSpeech;
      _selectedGroup = availableGroups.contains(draft.group)
          ? draft.group
          : null;
      _favorite = draft.favorite;
      _priority = draft.priority;
      _sentenceTokens = [...draft.sentenceTokens];
      _textController.text = draft.text;
      _meaningController.text = draft.meanings.join(', ');
      _acceptedController.text = draft.acceptedAnswers.join(', ');
      _readingController.text = draft.readings[ReadingScheme.hangul] ?? '';
      final subject = appController.activeSubject;
      _nativeReadingController.text =
          subject.contentLanguage == LanguageTag.simplifiedChinese
          ? draft.readings[ReadingScheme.pinyin] ?? ''
          : draft.readings[ReadingScheme.kana] ?? '';
      _romajiController.text = draft.readings[ReadingScheme.romaji] ?? '';
      _exampleController.text = draft.example;
      _exampleMeaningController.text = draft.exampleMeaning;
      _tagsController.text = draft.tags.join(', ');
      _basket = [
        for (final entry in draft.basket)
          _QuickBasketEntry(
            item: entry.item,
            favorite: entry.favorite,
            status: appController.findContentIdentityMatch(entry.item) == null
                ? _QuickBasketStatus.ready
                : _QuickBasketStatus.merge,
          ),
      ];
      _recoverableDraft = null;
    } finally {
      _suspendDraftRefresh = false;
    }
    setState(() {});
  }

  Future<void> _discardRecoveredDraft() async {
    await _clearPersistedDraftNow();
    if (mounted) setState(() => _recoverableDraft = null);
  }

  String _draftAgeLabel(DateTime updatedAt) {
    final elapsed = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (elapsed.inMinutes < 1) return '방금';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
    if (elapsed.inDays < 1) return '${elapsed.inHours}시간 전';
    return '${elapsed.inDays}일 전';
  }

  Future<void> _createTemplate(StudySubject subject) async {
    final name = await _askTemplateName(title: '현재 설정을 템플릿으로 저장');
    if (name == null || !mounted) return;
    final now = DateTime.now().toUtc();
    try {
      final template = QuickContentTemplate(
        id: 'template-${now.microsecondsSinceEpoch}',
        name: name,
        kind: _kind,
        partOfSpeech: _partOfSpeech,
        group: _selectedGroup,
        tags: _splitValues(_tagsController.text),
        favorite: _favorite,
        priority: _priority,
        createdAt: now,
        updatedAt: now,
      );
      final saved = await _saveQuickPreferences(
        _quickPreferences.saveTemplate(
          subjectId: subject.id,
          template: template,
        ),
      );
      if (saved) {
        _showMessage('“${template.name}” 템플릿을 이 기기에 저장했습니다.');
      }
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<String?> _askTemplateName({
    required String title,
    String initialValue = '',
  }) => showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _TemplateNameDialog(title: title, initialValue: initialValue),
  );

  Future<void> _applyTemplate(
    StudySubject subject,
    QuickContentTemplate template,
  ) async {
    final originalText = _textController.text;
    final originalMeanings = _meaningController.text;
    final availableGroups = ref
        .read(appControllerProvider.notifier)
        .availableLearningGroups
        .toSet();
    final groupAvailable =
        template.group == null || availableGroups.contains(template.group);
    _suspendDraftRefresh = true;
    try {
      _kind = template.kind;
      _partOfSpeech = template.partOfSpeech;
      _selectedGroup = groupAvailable ? template.group : null;
      _tagsController.text = template.tags.join(', ');
      _favorite = template.favorite;
      _priority = template.priority;
      if (_kind != LearningItemKind.sentence) _sentenceTokens = <String>[];
      // These assignments make the preservation guarantee explicit even if
      // template fields are expanded in a future release.
      _textController.text = originalText;
      _meaningController.text = originalMeanings;
    } finally {
      _suspendDraftRefresh = false;
    }
    setState(() {});
    _scheduleDraftSave();
    final remembered = await _saveQuickPreferences(
      _quickPreferences.saveTemplate(
        subjectId: subject.id,
        template: template.copyWith(updatedAt: DateTime.now()),
      ),
    );
    if (!groupAvailable) {
      _showMessage('템플릿의 삭제된 그룹은 제외하고 적용했습니다. 원문과 뜻은 유지했습니다.');
    } else if (!remembered) {
      _showMessage('설정은 적용했지만 최근 사용 순서는 다음에 다시 기억합니다.');
    } else {
      _showMessage('“${template.name}” 설정을 적용했습니다. 원문과 뜻은 유지했습니다.');
    }
  }

  Future<void> _handleTemplateAction(
    StudySubject subject,
    QuickContentTemplate template,
    _TemplateAction action,
  ) async {
    var next = _quickPreferences;
    switch (action) {
      case _TemplateAction.pin:
        next = next.toggleTemplatePinned(
          subjectId: subject.id,
          id: template.id,
        );
        break;
      case _TemplateAction.rename:
        final name = await _askTemplateName(
          title: '템플릿 이름 변경',
          initialValue: template.name,
        );
        if (name == null || !mounted) return;
        next = next.renameTemplate(
          subjectId: subject.id,
          id: template.id,
          name: name,
        );
        break;
      case _TemplateAction.duplicate:
        final name = await _askTemplateName(
          title: '템플릿 복제',
          initialValue: '${template.name} 복사본',
        );
        if (name == null || !mounted) return;
        final now = DateTime.now().toUtc();
        next = next.duplicateTemplate(
          subjectId: subject.id,
          sourceId: template.id,
          newId: 'template-${now.microsecondsSinceEpoch}',
          newName: name,
          at: now,
        );
        break;
      case _TemplateAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('quick-content-template-delete-dialog'),
            title: const Text('템플릿을 삭제할까요?'),
            content: Text('“${template.name}” 템플릿만 이 기기에서 삭제합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const Key('quick-content-template-delete-confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        next = next.deleteTemplate(subjectId: subject.id, id: template.id);
        break;
    }
    await _saveQuickPreferences(next);
  }

  void _changeTemplateSort(QuickContentTemplateSort sort) {
    unawaited(
      _saveQuickPreferences(_quickPreferences.copyWith(templateSort: sort)),
    );
  }

  Future<bool> _saveQuickPreferences(QuickContentLocalPreferences next) async {
    try {
      await ref.read(studyStoreProvider).saveQuickContentLocalPreferences(next);
      if (mounted) setState(() => _quickPreferences = next);
      return true;
    } on Object {
      _showMessage('기기 설정을 저장하지 못했습니다. 입력한 학습 자료는 그대로 유지됩니다.');
      return false;
    }
  }

  void _addToBasket(StudySubject subject) {
    if (_basket.length >= 50) {
      _showMessage('저장 목록에는 한 번에 50개까지 담을 수 있어요.');
      return;
    }
    final experience = ref.read(appControllerProvider).preferences.experience;
    if (experience.quickAddAutoNormalize) _applyNormalization();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tokenInspection = const SentenceTokenValidator().inspect(
      sentence: _textController.text,
      tokens: _kind == LearningItemKind.sentence
          ? _sentenceTokens
          : const <String>[],
    );
    if (!tokenInspection.canSave) {
      _showMessage(tokenInspection.message!);
      return;
    }
    final candidate = _candidate(subject);
    final validator = const LearningContentValidator();
    final key = validator.identityKey(candidate);
    if (_basket.any((entry) => validator.identityKey(entry.item) == key)) {
      _showMessage('같은 표현이 저장 목록에 있어요. 기존 항목을 확인해 주세요.');
      return;
    }
    final duplicate = ref
        .read(appControllerProvider.notifier)
        .findContentIdentityMatch(candidate);
    setState(() {
      _basket = [
        ..._basket,
        _QuickBasketEntry(
          item: candidate,
          favorite: _favorite,
          status: duplicate == null
              ? _QuickBasketStatus.ready
              : _QuickBasketStatus.merge,
        ),
      ];
      _clearEntryFields(keepMetadata: true);
    });
    _clipboardSession.confirm();
    unawaited(_persistCurrentDraftNow());
    _textFocusNode.requestFocus();
  }

  void _clearEntryFields({required bool keepMetadata}) {
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
      _sentenceTokens = <String>[];
      _duplicateDecisionKey = null;
      _saveDuplicateSeparately = false;
      if (!keepMetadata) {
        _tagsController.clear();
        _selectedGroup = null;
      }
    } finally {
      _suspendDraftRefresh = false;
    }
  }

  void _removeBasketEntry(String id) {
    setState(() {
      _basket = _basket.where((entry) => entry.item.id != id).toList();
    });
    unawaited(_persistCurrentDraftNow());
  }

  void _applyCurrentOptionsToBasket() {
    if (_basket.isEmpty) return;
    final tags = <String>{..._splitValues(_tagsController.text)};
    if (_selectedGroup case final group?) tags.add(learningGroupTag(group));
    setState(() {
      _basket = [
        for (final entry in _basket)
          entry.copyWith(
            item: entry.item.copyWith(
              tags: tags.toList(growable: false),
              priority: _priority,
            ),
            favorite: _favorite,
          ),
      ];
    });
    unawaited(_persistCurrentDraftNow());
    _showMessage('${_basket.length}개에 현재 그룹·태그·즐겨찾기·우선순위를 적용했어요.');
  }

  Future<void> _saveBasket(StudySubject subject) async {
    if (_saving || _basket.isEmpty) return;
    setState(() => _saving = true);
    final controller = ref.read(appControllerProvider.notifier);
    final saved = <QuickContentSaveResult>[];
    try {
      for (final entry in _basket) {
        var result = await controller.saveQuickContent(entry.item);
        if (entry.favorite &&
            !ref
                .read(appControllerProvider)
                .preferences
                .isFavorite(result.item.id)) {
          controller.toggleFavorite(result.item.id);
          result = result.copyWith(favoriteAdded: true);
        }
        saved.add(result);
      }
      var preferenceSaveFailed = false;
      try {
        if (_selectedGroup case final group?) {
          await _rememberGroup(subject.id, group);
        }
        await _rememberEntryPreferences(
          subject.id,
          ref.read(appControllerProvider).preferences.experience,
        );
      } on Object {
        // The learning items are already safely stored. Local convenience
        // preferences must never turn a successful batch into a rollback.
        preferenceSaveFailed = true;
      }
      if (!mounted) return;
      _clipboardSession.confirm();
      _rememberSessionSaves(saved);
      setState(() => _basket = <_QuickBasketEntry>[]);
      if (_currentDraft().hasContent) {
        await _persistCurrentDraftNow();
      } else {
        setState(() => _cleanDraftFingerprint = _draftFingerprint());
        await _clearPersistedDraftNow();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preferenceSaveFailed
                ? '${saved.length}개를 저장했습니다. 최근 옵션은 다음에 다시 기억합니다.'
                : '${saved.length}개를 한꺼번에 저장했어요.',
          ),
          action: SnackBarAction(
            label: '모두 취소',
            onPressed: () => unawaited(_undoBatch(saved)),
          ),
        ),
      );
    } catch (error) {
      final restored = await _undoBatch(saved, announce: false);
      if (mounted) {
        _showMessage('저장이 중단되어 먼저 저장된 $restored개를 되돌렸어요. 저장 목록은 그대로예요. $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _rememberSessionSaves(Iterable<QuickContentSaveResult> results) {
    if (!mounted) return;
    setState(() {
      _sessionUndo = [
        ...results.toList().reversed,
        ..._sessionUndo,
      ].take(5).toList(growable: false);
    });
  }

  Future<void> _undoRecentSave(QuickContentSaveResult result) async {
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
    if (status != QuickContentUndoStatus.conflict) {
      setState(() {
        _sessionUndo = _sessionUndo
            .where((entry) => entry.undoToken.id != result.undoToken.id)
            .toList(growable: false);
      });
    }
    if (status != QuickContentUndoStatus.conflict) {
      setState(() {
        _sessionUndo = _sessionUndo
            .where((entry) => entry.undoToken.id != result.undoToken.id)
            .toList(growable: false);
      });
    }
    _showMessage(switch (status) {
      QuickContentUndoStatus.restored => '“${result.item.text}” 저장을 되돌렸습니다.',
      QuickContentUndoStatus.conflict => '저장한 뒤 수정된 자료라 자동으로 되돌리지 않았어요.',
      QuickContentUndoStatus.alreadyUndone => '이미 되돌린 저장입니다.',
    });
  }

  Future<void> _importClipboard(StudySubject subject) async {
    final clipboard = await _clipboardSession.readOnce(
      () async => (await Clipboard.getData(Clipboard.kTextPlain))?.text,
    );
    if (!mounted) return;
    if (clipboard.status != ClipboardReadStatus.accepted) {
      _showMessage(switch (clipboard.status) {
        ClipboardReadStatus.empty => '클립보드에 텍스트가 없습니다.',
        ClipboardReadStatus.alreadyRead => '이 창에서는 클립보드를 이미 한 번 읽었습니다.',
        ClipboardReadStatus.failed => '클립보드를 읽지 못했습니다.',
        ClipboardReadStatus.accepted => throw StateError('unreachable'),
      });
      return;
    }
    final text = clipboard.text!;
    BulkPasteResult parsed;
    try {
      parsed = const BulkPasteParser().parse(text);
    } on FormatException catch (error) {
      _clipboardSession.discard();
      _showMessage(error.message);
      return;
    }
    if (!parsed.canImport) {
      await _showClipboardIssues(parsed);
      _clipboardSession.discard();
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
      if (parsed.issues.isNotEmpty) {
        _showMessage('${parsed.issues.length}개 행은 확인이 필요해 제외했습니다.');
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ClipboardPairReviewDialog(result: parsed),
    );
    if (confirmed != true || !mounted) {
      _clipboardSession.discard();
      return;
    }
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
      _clipboardSession.confirm();
      _rememberSessionSaves(saved);
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
      _clipboardSession.discard();
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
      title: const Text('가져올 표현과 뜻을 찾지 못했어요'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('표현과 뜻을 탭이나 쉼표로 나누거나, 두 줄씩 한 쌍으로 입력해 주세요.'),
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
    if (draft.hasContent && !_clipboardSession.hasUnconfirmedContent) {
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
      _showMessage('발음을 제안하려면 읽는 법을 먼저 입력해 주세요.');
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
      QuickContentUndoStatus.conflict => '저장한 뒤 수정된 자료라 자동으로 되돌리지 않았어요.',
      QuickContentUndoStatus.alreadyUndone => '이미 되돌린 저장입니다.',
    });
  }

  Future<int> _undoBatch(
    List<QuickContentSaveResult> results, {
    bool announce = true,
  }) async {
    var restored = 0;
    final completedIds = <String>{};
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
      if (status != QuickContentUndoStatus.conflict) {
        completedIds.add(result.undoToken.id);
      }
    }
    if (mounted) {
      setState(() {
        _sessionUndo = _sessionUndo
            .where((entry) => !completedIds.contains(entry.undoToken.id))
            .toList(growable: false);
      });
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
      await _clearPersistedDraftNow();
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
        title: const Text('작성 중인 내용을 닫을까요?'),
        content: const Text('저장하지 않은 내용은 사라져요. 계속 작성하거나 버리고 나갈 수 있어요.'),
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
    await _clearPersistedDraftNow();
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
        _showNewGroupFields = false;
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
    final experience = ref.read(appControllerProvider).preferences.experience;
    if (experience.quickAddAutoNormalize) _applyNormalization();
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
      switch (experience.duplicateDefault) {
        case AppDuplicateDefault.ask:
          FocusScope.of(context).unfocus();
          _showMessage('같은 표현이 있어요. 뜻을 합칠지 따로 저장할지 골라 주세요.');
          return;
        case AppDuplicateDefault.merge:
          _duplicateDecisionKey = duplicateKey;
          _saveDuplicateSeparately = false;
          break;
        case AppDuplicateDefault.separate:
          _duplicateDecisionKey = duplicateKey;
          _saveDuplicateSeparately = true;
          break;
      }
    }
    setState(() => _saving = true);
    try {
      var result = await controller.saveQuickContent(
        candidate,
        allowDuplicate: duplicate != null && _saveDuplicateSeparately,
      );
      if (!mounted) return;
      var preferenceSaveFailed = false;
      if (_selectedGroup case final group?) {
        try {
          await _rememberGroup(subject.id, group);
        } on Object {
          preferenceSaveFailed = true;
        }
      }
      try {
        await _rememberEntryPreferences(subject.id, experience);
      } on Object {
        preferenceSaveFailed = true;
      }
      if (!mounted) return;
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
      _clipboardSession.confirm();
      _draftTimer?.cancel();
      if (!keepAdding) {
        if (_basket.isEmpty) {
          await _clearPersistedDraftNow();
        } else {
          setState(() => _clearEntryFields(keepMetadata: true));
          await _persistCurrentDraftNow();
        }
        if (!mounted) return;
        if (preferenceSaveFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('자료는 저장했습니다. 최근 등록 기본값은 다음 저장 때 다시 기억합니다.'),
            ),
          );
        }
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.pop(context, result);
        return;
      }
      _rememberSessionSaves([result]);
      final savedMessage = result.mergedWithExisting
          ? result.addedMeaningCount > 0
                ? '기존 표현에 새 뜻을 추가했어요.'
                : '같은 표현과 뜻이 이미 있어 한 번만 저장했어요.'
          : '저장했어요. 같은 그룹에 계속 추가할 수 있어요.';
      final message = preferenceSaveFailed
          ? '$savedMessage 최근 등록 기본값은 다음에 다시 기억합니다.'
          : savedMessage;
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
        if (!experience.quickAddRememberTags) _tagsController.clear();
        _favorite = experience.quickAddFavoriteDefault;
        _priority = experience.quickAddPriorityDefault;
        _duplicateDecisionKey = null;
        _saveDuplicateSeparately = false;
        _sentenceTokens = <String>[];
      } finally {
        _suspendDraftRefresh = false;
      }
      if (_basket.isEmpty) {
        await _clearPersistedDraftNow();
        if (!mounted) return;
        setState(() => _cleanDraftFingerprint = _draftFingerprint());
      } else {
        await _persistCurrentDraftNow();
        if (mounted) setState(() {});
      }
      if (!mounted) return;
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

  LearningItemKind _initialKind(AppQuickAddKind preference) =>
      switch (preference) {
        AppQuickAddKind.word ||
        AppQuickAddKind.lastUsed => LearningItemKind.word,
        AppQuickAddKind.sentence => LearningItemKind.sentence,
      };

  void _appendRecentTag(String tag) {
    final values = <String>{..._splitValues(_tagsController.text), tag};
    _tagsController.text = values.join(', ');
    _tagsController.selection = TextSelection.collapsed(
      offset: _tagsController.text.length,
    );
  }

  String _tagSuggestionQuery() {
    final parts = _tagsController.text.split(RegExp(r'[,;\n]'));
    return parts.isEmpty ? '' : parts.last.trim();
  }

  void _applyExampleSuggestion(LearningItem item) {
    _suspendDraftRefresh = true;
    try {
      _exampleController.text = item.text;
      _exampleMeaningController.text = item.translations.isEmpty
          ? ''
          : item.translations.first;
      _detailsExpanded = true;
    } finally {
      _suspendDraftRefresh = false;
    }
    setState(() {});
    _detailsTileController.expand();
    _scheduleDraftSave();
  }

  Future<void> _rememberEntryPreferences(
    String subjectId,
    AppExperiencePreferences experience,
  ) async {
    var next = _quickPreferences.rememberKind(
      subjectId: subjectId,
      kind: _kind,
    );
    if (experience.quickAddRememberTags) {
      next = next.rememberTags(
        subjectId: subjectId,
        tags: _splitValues(_tagsController.text),
      );
    }
    _quickPreferences = next;
    await ref.read(studyStoreProvider).saveQuickContentLocalPreferences(next);
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

enum _TemplateAction { pin, rename, duplicate, delete }

enum _QuickBasketStatus { ready, merge }

class _QuickInputFocusStatus extends StatelessWidget {
  const _QuickInputFocusStatus({required this.kind, required this.basketCount});

  final LearningItemKind kind;
  final int basketCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('quick-content-keyboard-focus-mode'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            kind == LearningItemKind.word
                ? Icons.text_fields_rounded
                : Icons.notes_rounded,
            size: 17,
            color: colors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              kind == LearningItemKind.word ? '단어 집중 입력' : '문장 집중 입력',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Icon(Icons.shopping_basket_outlined, size: 16, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            '저장 목록 $basketCount',
            key: const Key('quick-content-focus-basket-count'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _QuickBasketEntry {
  const _QuickBasketEntry({
    required this.item,
    required this.favorite,
    required this.status,
  });

  final LearningItem item;
  final bool favorite;
  final _QuickBasketStatus status;

  _QuickBasketEntry copyWith({
    LearningItem? item,
    bool? favorite,
    _QuickBasketStatus? status,
  }) => _QuickBasketEntry(
    item: item ?? this.item,
    favorite: favorite ?? this.favorite,
    status: status ?? this.status,
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('quick-content-template-name-dialog'),
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: const Key('quick-content-template-name'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        validator: (value) {
          final normalized = value?.trim() ?? '';
          if (normalized.isEmpty) return '템플릿 이름을 입력해 주세요.';
          if (normalized.runes.length > 40) {
            return '템플릿 이름은 40자 이하여야 합니다.';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '템플릿 이름',
          hintText: '예: 여행 단어 · 즐겨찾기',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('quick-content-template-name-confirm'),
        onPressed: _submit,
        child: const Text('저장'),
      ),
    ],
  );
}

class _QuickRegistrationWorkbench extends StatelessWidget {
  const _QuickRegistrationWorkbench({
    required this.templates,
    required this.templateSort,
    required this.basket,
    required this.recentSaves,
    required this.saving,
    required this.onCreateTemplate,
    required this.onApplyTemplate,
    required this.onTemplateAction,
    required this.onSortChanged,
    required this.onRemoveBasket,
    required this.onApplyBatchOptions,
    required this.onSaveBasket,
    required this.onUndo,
  });

  final List<QuickContentTemplate> templates;
  final QuickContentTemplateSort templateSort;
  final List<_QuickBasketEntry> basket;
  final List<QuickContentSaveResult> recentSaves;
  final bool saving;
  final VoidCallback onCreateTemplate;
  final ValueChanged<QuickContentTemplate> onApplyTemplate;
  final void Function(QuickContentTemplate, _TemplateAction) onTemplateAction;
  final ValueChanged<QuickContentTemplateSort> onSortChanged;
  final ValueChanged<String> onRemoveBasket;
  final VoidCallback onApplyBatchOptions;
  final VoidCallback onSaveBasket;
  final ValueChanged<QuickContentSaveResult> onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compactLayout =
        MediaQuery.sizeOf(context).width < 430 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('quick-content-workbench'),
        initiallyExpanded: basket.isNotEmpty,
        title: const Text('저장 도구'),
        subtitle: Text(
          '템플릿 ${templates.length} · 저장 목록 ${basket.length} · 되돌리기 ${recentSaves.length}/5',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (compactLayout) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '내 템플릿',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const Key('quick-content-template-create'),
                  onPressed: onCreateTemplate,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: '현재 설정을 템플릿으로 저장',
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<QuickContentTemplateSort>(
                key: const Key('quick-content-template-sort'),
                value: templateSort,
                items: const [
                  DropdownMenuItem(
                    value: QuickContentTemplateSort.recent,
                    child: Text('최근 사용순'),
                  ),
                  DropdownMenuItem(
                    value: QuickContentTemplateSort.name,
                    child: Text('이름순'),
                  ),
                  DropdownMenuItem(
                    value: QuickContentTemplateSort.created,
                    child: Text('생성순'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '내 템플릿',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                DropdownButton<QuickContentTemplateSort>(
                  key: const Key('quick-content-template-sort'),
                  value: templateSort,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: QuickContentTemplateSort.recent,
                      child: Text('최근 사용순'),
                    ),
                    DropdownMenuItem(
                      value: QuickContentTemplateSort.name,
                      child: Text('이름순'),
                    ),
                    DropdownMenuItem(
                      value: QuickContentTemplateSort.created,
                      child: Text('생성순'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
                IconButton(
                  key: const Key('quick-content-template-create'),
                  onPressed: onCreateTemplate,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: '현재 설정을 템플릿으로 저장',
                ),
              ],
            ),
          if (templates.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('자주 쓰는 그룹·태그 설정을 저장해 두고 다시 사용할 수 있어요.'),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 196),
              child: ListView.builder(
                key: const Key('quick-content-template-list'),
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final details = [
                    template.kind == LearningItemKind.word ? '단어' : '문장',
                    if (template.group != null) template.group!,
                    if (template.tags.isNotEmpty) template.tags.join(' · '),
                    if (template.favorite) '즐겨찾기',
                    '우선순위 ${template.priority}',
                  ].join(' · ');
                  return ListTile(
                    key: Key('quick-content-template-${template.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      template.pinned
                          ? Icons.push_pin_rounded
                          : Icons.bookmark_outline_rounded,
                      size: 20,
                    ),
                    title: Text(template.name),
                    subtitle: Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onApplyTemplate(template),
                    trailing: PopupMenuButton<_TemplateAction>(
                      key: Key('quick-content-template-menu-${template.id}'),
                      tooltip: '${template.name} 관리',
                      onSelected: (action) =>
                          onTemplateAction(template, action),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _TemplateAction.pin,
                          child: Text(template.pinned ? '고정 해제' : '상단 고정'),
                        ),
                        const PopupMenuItem(
                          value: _TemplateAction.rename,
                          child: Text('이름 변경'),
                        ),
                        const PopupMenuItem(
                          value: _TemplateAction.duplicate,
                          child: Text('복제'),
                        ),
                        const PopupMenuItem(
                          value: _TemplateAction.delete,
                          child: Text('삭제'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(),
          if (compactLayout)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('저장 목록', style: Theme.of(context).textTheme.titleSmall),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('quick-content-basket-apply-options'),
                    onPressed: basket.isEmpty ? null : onApplyBatchOptions,
                    child: const Text('현재 옵션 일괄 적용'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '저장 목록',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  key: const Key('quick-content-basket-apply-options'),
                  onPressed: basket.isEmpty ? null : onApplyBatchOptions,
                  child: const Text('현재 옵션 일괄 적용'),
                ),
              ],
            ),
          if (basket.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('여러 표현을 모아 확인한 뒤 한 번에 저장할 수 있어요.'),
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: ListView.builder(
                key: const Key('quick-content-basket-list'),
                shrinkWrap: true,
                itemCount: basket.length,
                itemBuilder: (context, index) {
                  final entry = basket[index];
                  final merging = entry.status == _QuickBasketStatus.merge;
                  return ListTile(
                    key: Key('quick-content-basket-${entry.item.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.item.text),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.item.translations.join(', ')),
                        const SizedBox(height: 4),
                        Wrap(
                          key: Key(
                            'quick-content-basket-status-${entry.item.id}',
                          ),
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _BasketStatusBadge(
                              label: '필수 완료',
                              color: colors.primaryContainer,
                            ),
                            _BasketStatusBadge(
                              label: entry.item.readings.isEmpty
                                  ? '읽기 없음'
                                  : '읽기 ${entry.item.readings.length}',
                              color: colors.secondaryContainer,
                            ),
                            _BasketStatusBadge(
                              label:
                                  entry.item.kind == LearningItemKind.sentence
                                  ? '토큰 ${entry.item.sentenceTokens.length}'
                                  : '단어',
                              color: colors.surfaceContainerHighest,
                            ),
                            _BasketStatusBadge(
                              label: merging ? '중복 · 병합 예정' : '신규',
                              color: merging
                                  ? colors.tertiaryContainer
                                  : colors.primaryContainer,
                            ),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    minVerticalPadding: 8,
                    trailing: IconButton(
                      onPressed: () => onRemoveBasket(entry.item.id),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      tooltip: '저장 목록에서 빼기',
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('quick-content-basket-save-all'),
                onPressed: saving ? null : onSaveBasket,
                icon: const Icon(Icons.done_all_rounded),
                label: Text('${basket.length}개 모두 저장'),
              ),
            ),
          ],
          if (recentSaves.isNotEmpty) ...[
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '이번에 저장한 내용 되돌리기',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              key: const Key('quick-content-session-undo'),
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final result in recentSaves)
                  ActionChip(
                    key: Key('quick-content-undo-${result.undoToken.id}'),
                    avatar: const Icon(Icons.undo_rounded, size: 16),
                    label: Text(
                      result.item.text,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => onUndo(result),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BasketStatusBadge extends StatelessWidget {
  const _BasketStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _ContentSuggestions extends StatelessWidget {
  const _ContentSuggestions({
    required this.similarItems,
    required this.examples,
    required this.tags,
    required this.groups,
    required this.onOpenSimilar,
    required this.onUseExample,
    required this.onUseTag,
    required this.onUseGroup,
  });

  final List<({LearningItem item, double score})> similarItems;
  final List<LearningItem> examples;
  final List<String> tags;
  final List<String> groups;
  final ValueChanged<LearningItem> onOpenSimilar;
  final ValueChanged<LearningItem> onUseExample;
  final ValueChanged<String> onUseTag;
  final ValueChanged<String> onUseGroup;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('quick-content-suggestions'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('입력 추천', style: Theme.of(context).textTheme.titleSmall),
            if (similarItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('비슷한 기존 표현', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final match in similarItems)
                    ActionChip(
                      key: Key('quick-content-similar-${match.item.id}'),
                      avatar: const Icon(Icons.manage_search_rounded, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          '${match.item.text} · ${match.item.primaryTranslation} · '
                          '${(match.score * 100).round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      tooltip: '기존 자료 열기',
                      onPressed: () => onOpenSimilar(match.item),
                    ),
                ],
              ),
            ],
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('관련 그룹', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final group in groups)
                    ActionChip(
                      key: Key('quick-content-group-suggestion-$group'),
                      avatar: const Icon(Icons.folder_copy_outlined, size: 16),
                      label: Text(group),
                      tooltip: '$group 그룹 선택',
                      onPressed: () => onUseGroup(group),
                    ),
                ],
              ),
            ],
            if (examples.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '기존 예문 가져오기',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in examples)
                    ActionChip(
                      key: Key('quick-content-example-suggestion-${item.id}'),
                      avatar: const Icon(Icons.format_quote_rounded, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          item.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      tooltip: '예문과 뜻 채우기',
                      onPressed: () => onUseExample(item),
                    ),
                ],
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('추천 태그', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags)
                    ActionChip(
                      key: Key('quick-content-tag-suggestion-$tag'),
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(tag),
                      onPressed: () => onUseTag(tag),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DuplicateNotice extends StatefulWidget {
  const _DuplicateNotice({
    required this.item,
    required this.incoming,
    required this.defaultLabel,
    required this.mergeSelected,
    required this.separateSelected,
    required this.onMerge,
    required this.onOpen,
    required this.onSeparate,
  });

  final LearningItem item;
  final LearningItem incoming;
  final String defaultLabel;
  final bool mergeSelected;
  final bool separateSelected;
  final VoidCallback onMerge;
  final VoidCallback onOpen;
  final VoidCallback onSeparate;

  @override
  State<_DuplicateNotice> createState() => _DuplicateNoticeState();
}

class _DuplicateNoticeState extends State<_DuplicateNotice> {
  var _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final existing = widget.item.translations
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final added = widget.incoming.translations
        .where((value) => !existing.contains(value.trim().toLowerCase()))
        .length;
    final summary = _duplicateMergeSummary(widget.item, widget.incoming);
    return Container(
      key: const Key('quick-content-duplicate-notice'),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.merge_rounded, color: colors.tertiary, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  added > 0 ? '같은 표현 · 새 뜻 $added개 추가 가능' : '이미 같은 표현과 뜻이 있어요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                key: const Key('quick-content-duplicate-default'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.defaultLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              IconButton(
                key: const Key('quick-content-duplicate-details-toggle'),
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails
                      ? Icons.expand_less_rounded
                      : Icons.compare_arrows_rounded,
                ),
                tooltip: _showDetails ? '비교 접기' : '기존 자료와 상세 비교',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const Key('quick-content-merge-existing'),
                selected: widget.mergeSelected,
                onSelected: (_) => widget.onMerge(),
                avatar: const Icon(Icons.merge_rounded, size: 16),
                label: const Text('뜻 합치기'),
              ),
              ActionChip(
                key: const Key('quick-content-view-existing'),
                onPressed: widget.onOpen,
                avatar: const Icon(Icons.open_in_new_rounded, size: 16),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    '기존 · ${widget.item.primaryTranslation}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ChoiceChip(
                key: const Key('quick-content-save-separate'),
                selected: widget.separateSelected,
                onSelected: (_) => widget.onSeparate(),
                avatar: const Icon(Icons.call_split_rounded, size: 16),
                label: const Text('따로 저장'),
              ),
            ],
          ),
          if (_showDetails) ...[
            const Divider(height: 14),
            KeyedSubtree(
              key: const Key('quick-content-duplicate-details'),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final existingCard = _DuplicateSide(
                    label: '기존 자료',
                    item: widget.item,
                    highlighted: widget.mergeSelected,
                  );
                  final incomingCard = _DuplicateSide(
                    label: '새로 입력',
                    item: widget.incoming,
                    highlighted: widget.separateSelected,
                  );
                  if (constraints.maxWidth < 430) {
                    return Column(
                      children: [
                        existingCard,
                        const SizedBox(height: 6),
                        incomingCard,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: existingCard),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 18,
                        ),
                        child: Icon(Icons.compare_arrows_rounded, size: 18),
                      ),
                      Expanded(child: incomingCard),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              key: const Key('quick-content-merge-summary'),
              spacing: 6,
              runSpacing: 4,
              children: [
                _MergeSummaryChip(
                  key: const Key('quick-content-merge-summary-add'),
                  label: '추가',
                  fields: summary.added,
                  color: colors.primaryContainer,
                ),
                _MergeSummaryChip(
                  key: const Key('quick-content-merge-summary-keep'),
                  label: '유지',
                  fields: summary.kept,
                  color: colors.secondaryContainer,
                ),
                _MergeSummaryChip(
                  key: const Key('quick-content-merge-summary-conflict'),
                  label: '충돌',
                  fields: summary.conflicts,
                  color: colors.errorContainer,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DuplicateSide extends StatelessWidget {
  const _DuplicateSide({
    required this.label,
    required this.item,
    required this.highlighted,
  });

  final String label;
  final LearningItem item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('quick-content-duplicate-side-$label'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer.withValues(alpha: 0.7)
            : colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: highlighted ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
          _DuplicateField(
            label: '뜻',
            value: item.translations.isEmpty
                ? '없음'
                : item.translations.join(', '),
          ),
          _DuplicateField(
            label: '읽기',
            value: item.readings.isEmpty
                ? '없음'
                : item.readings.map((reading) => reading.value).join(', '),
          ),
          _DuplicateField(
            label: '예문',
            value: [?item.example, ?item.exampleTranslation].join(' / '),
          ),
          _DuplicateField(
            label: '태그',
            value: item.tags.isEmpty ? '없음' : item.tags.join(', '),
          ),
        ],
      ),
    );
  }
}

class _DuplicateField extends StatelessWidget {
  const _DuplicateField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      '$label · ${value.trim().isEmpty ? '없음' : value}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _MergeSummaryChip extends StatelessWidget {
  const _MergeSummaryChip({
    required this.label,
    required this.fields,
    required this.color,
    super.key,
  });

  final String label;
  final List<String> fields;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$label · ${fields.isEmpty ? '없음' : fields.join(', ')}',
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _DuplicateMergeSummary {
  const _DuplicateMergeSummary({
    required this.added,
    required this.kept,
    required this.conflicts,
  });

  final List<String> added;
  final List<String> kept;
  final List<String> conflicts;
}

_DuplicateMergeSummary _duplicateMergeSummary(
  LearningItem existing,
  LearningItem incoming,
) {
  final added = <String>[];
  final kept = <String>['표현'];
  final conflicts = <String>[];

  int newValues(Iterable<String> before, Iterable<String> after) {
    final known = before.map((value) => value.trim().toLowerCase()).toSet();
    return after
        .where((value) => !known.contains(value.trim().toLowerCase()))
        .length;
  }

  final meaningCount = newValues(existing.translations, incoming.translations);
  if (meaningCount > 0) {
    added.add('뜻 $meaningCount');
  } else {
    kept.add('뜻');
  }
  final readingCount = newValues(
    existing.readings.map(
      (reading) => '${reading.scheme.name}:${reading.value}',
    ),
    incoming.readings.map(
      (reading) => '${reading.scheme.name}:${reading.value}',
    ),
  );
  if (readingCount > 0) {
    added.add('읽기 $readingCount');
  } else if (existing.readings.isNotEmpty) {
    kept.add('읽기');
  }
  final tagCount = newValues(existing.tags, incoming.tags);
  if (tagCount > 0) {
    added.add('태그 $tagCount');
  } else if (existing.tags.isNotEmpty) {
    kept.add('태그');
  }

  void compareSingle(String label, String? before, String? after) {
    final oldValue = before?.trim() ?? '';
    final newValue = after?.trim() ?? '';
    if (newValue.isEmpty || oldValue == newValue) {
      if (oldValue.isNotEmpty) kept.add(label);
    } else if (oldValue.isEmpty) {
      added.add(label);
    } else {
      conflicts.add(label);
    }
  }

  compareSingle('예문', existing.example, incoming.example);
  compareSingle(
    '예문 뜻',
    existing.exampleTranslation,
    incoming.exampleTranslation,
  );
  return _DuplicateMergeSummary(
    added: List.unmodifiable(added),
    kept: List.unmodifiable(kept),
    conflicts: List.unmodifiable(conflicts),
  );
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
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 4, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.cleaning_services_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '문자·공백 정리 · $before → $after',
                maxLines: 1,
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
    title: Text('${result.entryCount}개를 저장할까요?'),
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
              '확인이 필요한 행은 빼고 저장해요. 첫 번째 문제: '
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
