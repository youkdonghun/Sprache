import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/content_validation.dart';
import '../domain/import_distribution.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/sentence_tokens.dart';
import '../domain/study_subject.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/navigation_guard_state.dart';
import '../widgets/sentence_token_editor.dart';

class ItemEditorScreen extends ConsumerStatefulWidget {
  const ItemEditorScreen({this.itemId, super.key});

  final String? itemId;

  @override
  ConsumerState<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends ConsumerState<ItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _translationController = TextEditingController();
  final _acceptedController = TextEditingController();
  final _readingController = TextEditingController();
  final _secondaryReadingController = TextEditingController();
  final _koreanPronunciationController = TextEditingController();
  final _exampleController = TextEditingController();
  final _exampleTranslationController = TextEditingController();
  final _tagsController = TextEditingController();
  final _levelController = TextEditingController(text: '입문');
  final _sourceNameController = TextEditingController(
    text: ContentSource.userCreated.name,
  );
  final _licenseController = TextEditingController(
    text: ContentSource.userCreated.license,
  );
  final _sourceVersionController = TextEditingController(
    text: ContentSource.userCreated.sourceVersion,
  );
  final _sourceIdController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _authorController = TextEditingController();
  final _attributionController = TextEditingController();

  var _kind = LearningItemKind.word;
  var _partOfSpeech = PartOfSpeech.noun;
  var _priority = 0;
  var _saving = false;
  var _exitDialogOpen = false;
  var _savedSuccessfully = false;
  var _sentenceTokens = <String>[];
  String? _selectedGroup;
  late String _subjectId;
  late final String _initialDraftFingerprint;
  late final NavigationGuardController _navigationGuard;
  LearningItem? _original;

  bool get _isEditing => _original != null;
  bool get _hasUnsavedChanges =>
      !_savedSuccessfully && _draftFingerprint() != _initialDraftFingerprint;

  @override
  void initState() {
    super.initState();
    _subjectId = ref.read(appControllerProvider).activeSubjectId;
    final itemId = widget.itemId;
    if (itemId != null) {
      final controller = ref.read(appControllerProvider.notifier);
      _original = controller.customItemById(itemId);
      if (_original == null) {
        for (final item in controller.courseItems) {
          if (item.id == itemId) {
            _original = item;
            break;
          }
        }
      }
      final item = _original;
      if (item != null) {
        _subjectId = item.effectiveSubjectId;
        _kind = item.kind;
        _partOfSpeech = item.partOfSpeech ?? PartOfSpeech.noun;
        _priority = item.priority;
        _textController.text = item.text;
        _sentenceTokens = [...item.sentenceTokens];
        _translationController.text = item.translations.join(', ');
        _acceptedController.text = item.acceptedAnswers.join(', ');
        _readingController.text = item.readings
            .where(
              (reading) =>
                  reading.scheme == ReadingScheme.kana ||
                  reading.scheme == ReadingScheme.pinyin,
            )
            .map((reading) => reading.value)
            .join(', ');
        _secondaryReadingController.text = item.readings
            .where((reading) => reading.scheme == ReadingScheme.romaji)
            .map((reading) => reading.value)
            .join(', ');
        _koreanPronunciationController.text =
            item.reading(ReadingScheme.hangul) ?? '';
        _exampleController.text = item.example ?? '';
        _exampleTranslationController.text = item.exampleTranslation ?? '';
        final itemGroups = learningGroupsOf(item);
        _selectedGroup = itemGroups.isEmpty ? null : itemGroups.first;
        _tagsController.text = item.tags
            .where(
              (tag) =>
                  !tag.startsWith(learningGroupTagPrefix) &&
                  !tag.startsWith(importDistributionTagPrefix),
            )
            .join(', ');
        _levelController.text = item.level;
        _sourceNameController.text = item.source.name;
        _licenseController.text = item.source.license;
        _sourceVersionController.text = item.source.sourceVersion;
        _sourceIdController.text = item.source.sourceId ?? '';
        _sourceUrlController.text = item.source.sourceUrl ?? '';
        _authorController.text = item.source.author ?? '';
        _attributionController.text = item.source.attribution ?? '';
      }
    }
    _initialDraftFingerprint = _draftFingerprint();
    _navigationGuard = ref.read(navigationGuardProvider)
      ..register(this, _confirmDiscardForNavigation);
  }

  @override
  void dispose() {
    _navigationGuard.unregister(this);
    _textController.dispose();
    _translationController.dispose();
    _acceptedController.dispose();
    _readingController.dispose();
    _secondaryReadingController.dispose();
    _koreanPronunciationController.dispose();
    _exampleController.dispose();
    _exampleTranslationController.dispose();
    _tagsController.dispose();
    _levelController.dispose();
    _sourceNameController.dispose();
    _licenseController.dispose();
    _sourceVersionController.dispose();
    _sourceIdController.dispose();
    _sourceUrlController.dispose();
    _authorController.dispose();
    _attributionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appControllerProvider);
    final appController = ref.read(appControllerProvider.notifier);
    final subjects = appController.availableSubjects;
    final groups = appController.availableLearningGroups;
    final subject = subjects.firstWhere(
      (candidate) => candidate.id == _subjectId,
      orElse: () => appController.activeSubject,
    );
    final language = subject.contentLanguage;
    final generalTopic = subject.kind == StudySubjectKind.general;
    if (widget.itemId != null && _original == null) {
      return _MissingItem(onBack: () => context.go('/library'));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: ListView(
                key: const Key('item-editor-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('item-editor-back-button'),
                        onPressed: _saving ? null : _requestExit,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: '자료실로 돌아가기',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? '표현 수정' : '새 표현 추가',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '${subject.symbol} ${subject.name} · 기기에 바로 저장됩니다.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _save(subject),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_isEditing ? '수정 저장' : '추가하기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '기본 정보',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            key: const Key('item-subject-field'),
                            initialValue: subject.id,
                            decoration: const InputDecoration(
                              labelText: '저장할 학습 주제',
                              helperText: '다른 주제를 선택하면 자료를 그 주제로 옮깁니다.',
                            ),
                            items: [
                              for (final candidate in subjects)
                                DropdownMenuItem(
                                  value: candidate.id,
                                  child: Text(
                                    '${candidate.symbol} ${candidate.name}',
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _subjectId = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<LearningItemKind>(
                            segments: [
                              ButtonSegment(
                                value: LearningItemKind.word,
                                icon: Icon(Icons.abc_rounded),
                                label: Text(generalTopic ? '개념' : '단어'),
                              ),
                              ButtonSegment(
                                value: LearningItemKind.sentence,
                                icon: Icon(Icons.subject_rounded),
                                label: Text(generalTopic ? '사실·문장' : '문장'),
                              ),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (selection) =>
                                setState(() => _kind = selection.first),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('item-text-field'),
                            controller: _textController,
                            autofocus: !_isEditing,
                            onChanged: (_) {
                              if (_kind == LearningItemKind.sentence) {
                                setState(() {});
                              }
                            },
                            decoration: InputDecoration(
                              labelText: _kind == LearningItemKind.word
                                  ? generalTopic
                                        ? '외울 개념·용어'
                                        : '${language.koreanName} 단어'
                                  : generalTopic
                                  ? '외울 사실·문장'
                                  : '${language.koreanName} 문장',
                              hintText: _kind == LearningItemKind.word
                                  ? generalTopic
                                        ? '예: WHIP'
                                        : '예: accomplish'
                                  : generalTopic
                                  ? '예: 야구는 9명씩 두 팀이 경기한다.'
                                  : '예: I finally accomplished my goal.',
                            ),
                            validator: _required,
                          ),
                          if (_kind == LearningItemKind.sentence) ...[
                            const SizedBox(height: 12),
                            SentenceTokenEditor(
                              sentenceText: _textController.text,
                              language: language,
                              tokens: _sentenceTokens,
                              onChanged: (tokens) =>
                                  setState(() => _sentenceTokens = tokens),
                            ),
                          ],
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'item-group-${_selectedGroup ?? 'none'}',
                            ),
                            initialValue: _selectedGroup ?? '__no_group__',
                            decoration: const InputDecoration(
                              labelText: '학습 그룹 (선택)',
                              helperText: '저장과 동시에 선택한 그룹에 넣습니다.',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '__no_group__',
                                child: Text('나중에 그룹 정리'),
                              ),
                              for (final group in groups)
                                DropdownMenuItem(
                                  value: group,
                                  child: Text(group),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _selectedGroup = value == '__no_group__'
                                  ? null
                                  : value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('item-translation-field'),
                            controller: _translationController,
                            decoration: const InputDecoration(
                              labelText: '한국어 뜻',
                              hintText: '여러 뜻은 쉼표로 구분',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _acceptedController,
                            decoration: const InputDecoration(
                              labelText: '정답으로 인정할 표현',
                              hintText: '비워두면 한국어 뜻을 그대로 사용',
                            ),
                          ),
                          if (_kind == LearningItemKind.word &&
                              !generalTopic) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<PartOfSpeech>(
                              key: const Key('item-part-of-speech-field'),
                              initialValue: _partOfSpeech,
                              decoration: const InputDecoration(
                                labelText: '품사',
                                helperText: '같은 철자의 다른 뜻과 용법을 구분합니다.',
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
                          if (language == LanguageTag.japanese ||
                              language == LanguageTag.simplifiedChinese) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('item-reading-field'),
                              controller: _readingController,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) => _readingInputError(
                                value,
                                language == LanguageTag.simplifiedChinese
                                    ? ReadingScheme.pinyin
                                    : ReadingScheme.kana,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    language == LanguageTag.simplifiedChinese
                                    ? '병음'
                                    : '가나 읽기',
                                hintText:
                                    language == LanguageTag.simplifiedChinese
                                    ? '예: shuǐ 또는 shui3'
                                    : '예: みず',
                                helperText: '여러 표기는 쉼표로 구분',
                              ),
                            ),
                            if (language == LanguageTag.japanese) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('item-secondary-reading-field'),
                                controller: _secondaryReadingController,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (value) => _readingInputError(
                                  value,
                                  ReadingScheme.romaji,
                                ),
                                decoration: const InputDecoration(
                                  labelText: '로마자',
                                  hintText: '예: mizu 또는 Tōkyō',
                                ),
                              ),
                            ],
                          ],
                          if (language != LanguageTag.korean) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('item-korean-pronunciation-field'),
                              controller: _koreanPronunciationController,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) => _readingInputError(
                                value,
                                ReadingScheme.hangul,
                              ),
                              decoration: InputDecoration(
                                labelText: '읽는 법 (한글 보조)',
                                hintText: _koreanPronunciationHint(language),
                                helperText:
                                    '한글 보조 표기 · 실제 소리는 듣기로 확인 · 여러 표기는 쉼표로 구분',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ExpansionTile(
                      key: const Key('item-memory-hints-section'),
                      title: const Text('암기 단서'),
                      subtitle: const Text('예문·태그·난이도 · 필요할 때만 입력'),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      children: [
                        TextFormField(
                          controller: _exampleController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '예문',
                            hintText: '이 표현이 쓰인 실제 문맥',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _exampleTranslationController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: '예문 해석'),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fields = [
                              TextFormField(
                                controller: _tagsController,
                                decoration: const InputDecoration(
                                  labelText: '태그',
                                  hintText: '업무, 여행, 시험',
                                ),
                              ),
                              TextFormField(
                                controller: _levelController,
                                decoration: const InputDecoration(
                                  labelText: '난이도',
                                  hintText: '입문, 초급, 중급',
                                ),
                              ),
                            ];
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  fields.first,
                                  const SizedBox(height: 12),
                                  fields.last,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: fields.first),
                                const SizedBox(width: 12),
                                Expanded(child: fields.last),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '학습 우선순위 $_priority',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Slider(
                          value: _priority.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: '$_priority',
                          onChanged: (value) =>
                              setState(() => _priority = value.round()),
                        ),
                        Text(
                          '높을수록 새 항목 큐에서 먼저 출제됩니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    key: const Key('item-source-card'),
                    child: ExpansionTile(
                      key: const Key('item-source-section'),
                      title: const Text('출처와 버전'),
                      subtitle: const Text('직접 입력은 기본값 그대로 저장 가능'),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      children: [
                        Text(
                          '사전·교재에서 가져온 경우 실제 출처와 이용 조건을 기록하세요.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final source = TextFormField(
                              key: const Key('item-source-name-field'),
                              controller: _sourceNameController,
                              decoration: const InputDecoration(
                                labelText: '출처 이름',
                                hintText: '사용자 직접 입력, 교재명, 사전명',
                              ),
                              validator: _required,
                            );
                            final license = TextFormField(
                              key: const Key('item-license-field'),
                              controller: _licenseController,
                              decoration: const InputDecoration(
                                labelText: '라이선스·이용 조건',
                                hintText: 'private, CC BY 4.0',
                              ),
                              validator: _required,
                            );
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  source,
                                  const SizedBox(height: 12),
                                  license,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: source),
                                const SizedBox(width: 12),
                                Expanded(child: license),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('item-source-version-field'),
                          controller: _sourceVersionController,
                          decoration: const InputDecoration(
                            labelText: '출처 버전',
                            hintText: '판·쇄·데이터셋 버전, 예: 2026.1',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final sourceId = TextFormField(
                              key: const Key('item-source-id-field'),
                              controller: _sourceIdController,
                              decoration: const InputDecoration(
                                labelText: '원문 ID (선택)',
                                hintText: '예: Tatoeba 13911834 / 번역 13911832',
                              ),
                            );
                            final author = TextFormField(
                              key: const Key('item-source-author-field'),
                              controller: _authorController,
                              decoration: const InputDecoration(
                                labelText: '작성자 (선택)',
                                hintText: '원문과 번역 작성자',
                              ),
                            );
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  sourceId,
                                  const SizedBox(height: 12),
                                  author,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: sourceId),
                                const SizedBox(width: 12),
                                Expanded(child: author),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('item-source-url-field'),
                          controller: _sourceUrlController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: '원문 URL (선택)',
                            hintText:
                                'https://tatoeba.org/ko/sentences/show/...',
                          ),
                          validator: _optionalHttpUrl,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('item-attribution-field'),
                          controller: _attributionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '출처 표시문 (선택)',
                            hintText: '공유·내보내기 때 함께 남길 저자·라이선스 안내',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _original == null
                                ? '콘텐츠 버전 1로 저장됩니다.'
                                : '현재 콘텐츠 버전 ${_original!.source.contentVersion} · 수정 저장 시 자동으로 증가합니다.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const Key('item-editor-bottom-save'),
                    onPressed: _saving ? null : () => _save(subject),
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_isEditing ? '수정 내용 저장' : '자료 저장'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
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
    _subjectId,
    _kind.name,
    _partOfSpeech.name,
    _priority,
    _selectedGroup,
    _sentenceTokens.join('\u001e'),
    _textController.text,
    _translationController.text,
    _acceptedController.text,
    _readingController.text,
    _secondaryReadingController.text,
    _koreanPronunciationController.text,
    _exampleController.text,
    _exampleTranslationController.text,
    _tagsController.text,
    _levelController.text,
    _sourceNameController.text,
    _licenseController.text,
    _sourceVersionController.text,
    _sourceIdController.text,
    _sourceUrlController.text,
    _authorController.text,
    _attributionController.text,
  ].join('\u001f');

  Future<void> _requestExit() async {
    if (await _confirmDiscardForNavigation() && mounted) {
      context.go('/library');
    }
  }

  Future<bool> _confirmDiscardForNavigation() async {
    if (_saving || _exitDialogOpen || !mounted) return false;
    if (!_hasUnsavedChanges) return true;
    _exitDialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('item-editor-unsaved-dialog'),
        title: const Text('작성 중인 내용을 나갈까요?'),
        content: const Text(
          '저장하지 않은 입력 내용은 사라집니다. 계속 작성하거나, 내용을 버리고 나갈 수 있어요.',
        ),
        actions: [
          TextButton(
            key: const Key('item-editor-keep-editing'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            key: const Key('item-editor-discard-and-exit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('버리고 나가기'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || discard != true) return false;
    _savedSuccessfully = true;
    return true;
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  String? _optionalHttpUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        !const {'http', 'https'}.contains(uri.scheme)) {
      return 'http 또는 https 원문 주소를 입력하세요.';
    }
    return null;
  }

  String? _readingInputError(String? value, ReadingScheme scheme) {
    for (final reading in _splitValues(value ?? '')) {
      final issue = inspectReadingFormat(scheme, reading);
      if (issue != null) return issue.message;
    }
    return null;
  }

  Future<void> _save(StudySubject subject) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final language = subject.contentLanguage;
    final text = _textController.text.trim();
    final translations = _splitValues(_translationController.text);
    final accepted = _splitValues(_acceptedController.text);
    final readings = _buildReadings(language);
    final tokenInspection = const SentenceTokenValidator().inspect(
      sentence: text,
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
    setState(() => _saving = true);
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
    final item = LearningItem(
      id:
          _original?.id ??
          'user-${language.code}-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      kind: _kind,
      learningLanguage: language,
      subjectId: subject.id,
      text: text,
      translations: translations,
      acceptedAnswers: accepted.isEmpty ? translations : accepted,
      readings: readings,
      sentenceTokens: sentenceTokens,
      example: _nullable(_exampleController.text),
      exampleTranslation: _nullable(_exampleTranslationController.text),
      partOfSpeech: _kind == LearningItemKind.word ? _partOfSpeech : null,
      tags: [
        ..._splitValues(_tagsController.text),
        if (_selectedGroup case final group?) learningGroupTag(group),
        if (_original case final original?)
          ...original.tags.where(
            (tag) => tag.startsWith(importDistributionTagPrefix),
          ),
      ],
      level: _nullable(_levelController.text) ?? '입문',
      capabilities: capabilities,
      priority: _priority,
      source: ContentSource(
        name: _sourceNameController.text,
        license: _licenseController.text,
        sourceVersion: _sourceVersionController.text,
        contentVersion: _original?.source.contentVersion ?? 1,
        sourceId: _nullable(_sourceIdController.text),
        sourceUrl: _nullable(_sourceUrlController.text),
        author: _nullable(_authorController.text),
        attribution: _nullable(_attributionController.text),
      ),
    );
    try {
      final controller = ref.read(appControllerProvider.notifier);
      final quickResult = _isEditing
          ? null
          : await controller.saveQuickContent(item);
      if (_isEditing) await controller.upsertCustomItem(item);
      if (!mounted) return;
      if (ref.read(appControllerProvider).driveConnected) {
        unawaited(
          ref.read(connectionControllerProvider.notifier).syncAutomatically(),
        );
      }
      final savedMessage = quickResult?.mergedWithExisting == true
          ? quickResult!.addedMeaningCount > 0
                ? '같은 표현이 있어 기존 자료에 새 뜻을 추가했습니다.'
                : '같은 표현과 뜻이 이미 있어 중복 저장하지 않았습니다.'
          : _isEditing
          ? '표현을 수정했습니다.'
          : '새 표현을 추가했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(savedMessage)));
      _savedSuccessfully = true;
      context.go(
        Uri(
          path: '/library',
          queryParameters: {'subject': item.subjectId, 'q': item.text},
        ).toString(),
      );
    } on LearningContentValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Reading> _buildReadings(LanguageTag language) {
    final koreanReadings = [
      for (final value in _splitValues(_koreanPronunciationController.text))
        Reading(scheme: ReadingScheme.hangul, value: value),
    ];
    if (language == LanguageTag.japanese) {
      return [
        for (final value in _splitValues(_readingController.text))
          Reading(scheme: ReadingScheme.kana, value: value),
        for (final value in _splitValues(_secondaryReadingController.text))
          Reading(scheme: ReadingScheme.romaji, value: value),
        ...koreanReadings,
      ];
    }
    if (language == LanguageTag.simplifiedChinese) {
      return [
        for (final value in _splitValues(_readingController.text))
          Reading(scheme: ReadingScheme.pinyin, value: value),
        ...koreanReadings,
      ];
    }
    if (language == LanguageTag.korean) return const [];
    return koreanReadings;
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

  List<String> _splitValues(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList(growable: false);

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _MissingItem extends StatelessWidget {
  const _MissingItem({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(
            '수정할 사용자 표현을 찾지 못했습니다.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('자료실로 돌아가기')),
        ],
      ),
    );
  }
}
