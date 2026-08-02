import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/language.dart';
import '../domain/sentence_tokens.dart';

class SentenceTokenEditor extends StatefulWidget {
  const SentenceTokenEditor({
    required this.sentenceText,
    required this.language,
    required this.tokens,
    required this.onChanged,
    super.key,
  });

  final String sentenceText;
  final LanguageTag language;
  final List<String> tokens;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SentenceTokenEditor> createState() => _SentenceTokenEditorState();
}

class _SentenceTokenEditorState extends State<SentenceTokenEditor> {
  final _tokenController = TextEditingController();
  final _parser = const SentenceTokenParser();
  final _validator = const SentenceTokenValidator();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _addToken() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    widget.onChanged(List.unmodifiable([...widget.tokens, token]));
    _tokenController.clear();
  }

  void _removeToken(int index) {
    final next = [...widget.tokens]..removeAt(index);
    widget.onChanged(List.unmodifiable(next));
  }

  void _moveToken(int from, int to) {
    if (to < 0 || to >= widget.tokens.length) return;
    final next = [...widget.tokens];
    final token = next.removeAt(from);
    next.insert(to, token);
    widget.onChanged(List.unmodifiable(next));
  }

  Future<void> _editToken(int index) async {
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _EditTokenDialog(initialValue: widget.tokens[index]),
    );
    final normalized = edited?.trim() ?? '';
    if (!mounted || normalized.isEmpty) return;
    final next = [...widget.tokens]..[index] = normalized;
    widget.onChanged(List.unmodifiable(next));
  }

  Future<void> _suggestFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final source = data?.text ?? '';
    if (source.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('클립보드에 문장이 없어요.')));
      return;
    }
    await _applySuggestion(source, sourceLabel: '클립보드');
  }

  Future<void> _suggestFromSentence() =>
      _applySuggestion(widget.sentenceText, sourceLabel: '현재 문장');

  Future<void> _applySuggestion(
    String source, {
    required String sourceLabel,
  }) async {
    final suggestion = _parser.suggest(source, language: widget.language);
    if (suggestion.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$sourceLabel에서 토큰을 만들 수 없어요.')));
      return;
    }
    if (widget.tokens.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('sentence-token-replace-dialog'),
          title: const Text('현재 토큰을 바꿀까요?'),
          content: Text(
            '$sourceLabel에서 ${suggestion.length}개를 제안했어요. '
            '적용한 뒤에도 각 토큰을 수정하거나 순서를 바꿀 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const Key('sentence-token-replace-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('제안으로 교체'),
            ),
          ],
        ),
      );
      if (!mounted || replace != true) return;
    }
    widget.onChanged(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _validator.inspect(
      sentence: widget.sentenceText,
      tokens: widget.tokens,
    );
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('sentence-token-editor'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inspection.canSave ? colors.outlineVariant : colors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '문장 배열 토큰',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Chip(label: Text('${widget.tokens.length}개')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '자동 분절하지 않습니다. 문장 배열 문제에서 하나씩 '
            '선택할 단위를 직접 확인해 저장하세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('sentence-token-suggest-from-text'),
                onPressed: widget.sentenceText.trim().isEmpty
                    ? null
                    : _suggestFromSentence,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('현재 문장에서 제안'),
              ),
              OutlinedButton.icon(
                key: const Key('sentence-token-paste'),
                onPressed: _suggestFromClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('클립보드에서 제안'),
              ),
            ],
          ),
          if (widget.tokens.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, token) in widget.tokens.indexed)
                  _EditableTokenChip(
                    index: index,
                    token: token,
                    canMoveLeft: index > 0,
                    canMoveRight: index < widget.tokens.length - 1,
                    onEdit: () => _editToken(index),
                    onDelete: () => _removeToken(index),
                    onMoveLeft: () => _moveToken(index, index - 1),
                    onMoveRight: () => _moveToken(index, index + 1),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('sentence-token-add-field'),
                  controller: _tokenController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addToken(),
                  decoration: const InputDecoration(
                    labelText: '토큰 직접 추가',
                    hintText: '예: accomplished',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const Key('sentence-token-add'),
                onPressed: _addToken,
                icon: const Icon(Icons.add_rounded),
                tooltip: '토큰 추가',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inspection.message ??
                (inspection.enablesSentenceExercises
                    ? '문장 배열과 빈칸 문제에 사용할 수 있어요.'
                    : '토큰을 비우면 문장 배열과 빈칸 문제를 사용하지 않아요.'),
            key: const Key('sentence-token-validation'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: inspection.canSave
                  ? colors.onSurfaceVariant
                  : colors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditTokenDialog extends StatefulWidget {
  const _EditTokenDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_EditTokenDialog> createState() => _EditTokenDialogState();
}

class _EditTokenDialogState extends State<_EditTokenDialog> {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('sentence-token-edit-dialog'),
      title: const Text('토큰 수정'),
      content: TextField(
        key: const Key('sentence-token-edit-field'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value),
        decoration: const InputDecoration(labelText: '토큰'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('sentence-token-edit-save'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _EditableTokenChip extends StatelessWidget {
  const _EditableTokenChip({
    required this.index,
    required this.token,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  final int index;
  final String token;
  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InputChip(
            key: Key('sentence-token-chip-$index'),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                '${index + 1}. $token',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onPressed: onEdit,
            onDeleted: onDelete,
            tooltip: '토큰 수정',
            side: BorderSide.none,
            backgroundColor: Colors.transparent,
          ),
          IconButton(
            key: Key('sentence-token-move-left-$index'),
            onPressed: canMoveLeft ? onMoveLeft : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            tooltip: '앞으로 이동',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            key: Key('sentence-token-move-right-$index'),
            onPressed: canMoveRight ? onMoveRight : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            tooltip: '뒤로 이동',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
