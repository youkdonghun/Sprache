import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/content_validation.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';

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

  var _kind = LearningItemKind.word;
  var _partOfSpeech = PartOfSpeech.noun;
  var _priority = 0;
  var _saving = false;
  LearningItem? _original;

  bool get _isEditing => _original != null;

  @override
  void initState() {
    super.initState();
    final itemId = widget.itemId;
    if (itemId != null) {
      _original = ref
          .read(appControllerProvider.notifier)
          .customItemById(itemId);
      final item = _original;
      if (item != null) {
        _kind = item.kind;
        _partOfSpeech = item.partOfSpeech ?? PartOfSpeech.noun;
        _priority = item.priority;
        _textController.text = item.text;
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
        _exampleController.text = item.example ?? '';
        _exampleTranslationController.text = item.exampleTranslation ?? '';
        _tagsController.text = item.tags.join(', ');
        _levelController.text = item.level;
        _sourceNameController.text = item.source.name;
        _licenseController.text = item.source.license;
        _sourceVersionController.text = item.source.sourceVersion;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _translationController.dispose();
    _acceptedController.dispose();
    _readingController.dispose();
    _secondaryReadingController.dispose();
    _exampleController.dispose();
    _exampleTranslationController.dispose();
    _tagsController.dispose();
    _levelController.dispose();
    _sourceNameController.dispose();
    _licenseController.dispose();
    _sourceVersionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appControllerProvider).selectedLanguage;
    if (widget.itemId != null && _original == null) {
      return _MissingItem(onBack: () => context.go('/library'));
    }

    return SafeArea(
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
                      onPressed: () => context.go('/library'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: '단어장으로 돌아가기',
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
                            '${language.koreanName} 코스 · 기기에 바로 저장됩니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(language),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                        SegmentedButton<LearningItemKind>(
                          segments: const [
                            ButtonSegment(
                              value: LearningItemKind.word,
                              icon: Icon(Icons.abc_rounded),
                              label: Text('단어'),
                            ),
                            ButtonSegment(
                              value: LearningItemKind.sentence,
                              icon: Icon(Icons.subject_rounded),
                              label: Text('문장'),
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
                          decoration: InputDecoration(
                            labelText: _kind == LearningItemKind.word
                                ? '${language.koreanName} 단어'
                                : '${language.koreanName} 문장',
                            hintText: _kind == LearningItemKind.word
                                ? '예: accomplish'
                                : '예: I finally accomplished my goal.',
                          ),
                          validator: _required,
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
                        if (_kind == LearningItemKind.word) ...[
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
                        if (LanguageProfile.of(
                          language,
                        ).readingSchemes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _readingController,
                            decoration: InputDecoration(
                              labelText:
                                  language == LanguageTag.simplifiedChinese
                                  ? '병음'
                                  : '가나 읽기',
                              hintText: '여러 표기는 쉼표로 구분',
                            ),
                          ),
                          if (language == LanguageTag.japanese) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _secondaryReadingController,
                              decoration: const InputDecoration(
                                labelText: '로마자',
                                hintText: '예: mizu',
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '암기 단서',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
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
                ),
                const SizedBox(height: 14),
                Card(
                  key: const Key('item-source-card'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '출처와 버전',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '직접 만든 표현은 private로 두고, 사전·교재에서 가져온 경우 실제 출처와 이용 조건을 기록하세요.',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  Future<void> _save(LanguageTag language) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final text = _textController.text.trim();
    final translations = _splitValues(_translationController.text);
    final accepted = _splitValues(_acceptedController.text);
    final readings = _buildReadings(language);
    final sentenceTokens = _kind == LearningItemKind.sentence
        ? _tokenize(text, language)
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
    final item = LearningItem(
      id:
          _original?.id ??
          'user-${language.code}-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      kind: _kind,
      learningLanguage: language,
      text: text,
      translations: translations,
      acceptedAnswers: accepted.isEmpty ? translations : accepted,
      readings: readings,
      sentenceTokens: sentenceTokens,
      example: _nullable(_exampleController.text),
      exampleTranslation: _nullable(_exampleTranslationController.text),
      partOfSpeech: _kind == LearningItemKind.word ? _partOfSpeech : null,
      tags: _splitValues(_tagsController.text),
      level: _nullable(_levelController.text) ?? '입문',
      capabilities: capabilities,
      priority: _priority,
      source: ContentSource(
        name: _sourceNameController.text,
        license: _licenseController.text,
        sourceVersion: _sourceVersionController.text,
        contentVersion: _original?.source.contentVersion ?? 1,
      ),
    );
    try {
      await ref.read(appControllerProvider.notifier).upsertCustomItem(item);
      if (!mounted) return;
      if (ref.read(appControllerProvider).driveConnected) {
        unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '표현을 수정했습니다.' : '새 표현을 추가했습니다.')),
      );
      context.go('/library');
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
    if (language == LanguageTag.japanese) {
      return [
        for (final value in _splitValues(_readingController.text))
          Reading(scheme: ReadingScheme.kana, value: value),
        for (final value in _splitValues(_secondaryReadingController.text))
          Reading(scheme: ReadingScheme.romaji, value: value),
      ];
    }
    if (language == LanguageTag.simplifiedChinese) {
      return [
        for (final value in _splitValues(_readingController.text))
          Reading(scheme: ReadingScheme.pinyin, value: value),
      ];
    }
    return const [];
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
          FilledButton(onPressed: onBack, child: const Text('단어장으로 돌아가기')),
        ],
      ),
    );
  }
}
