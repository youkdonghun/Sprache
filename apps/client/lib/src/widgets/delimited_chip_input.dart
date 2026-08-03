import 'package:flutter/material.dart';

class DelimitedChipInput extends StatelessWidget {
  const DelimitedChipInput({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.labelText,
    required this.hintText,
    this.required = false,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.helperText = '여러 답은 쉼표로 나눠 입력하세요.',
    this.suffixIcon,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String labelText;
  final String hintText;
  final bool required;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final String? helperText;
  final Widget? suffixIcon;

  static List<String> parse(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final values = parse(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            helperText: helperText,
            suffixIcon: suffixIcon,
          ),
          validator: required
              ? (value) => value == null || parse(value).isEmpty
                    ? '답을 하나 이상 입력해 주세요.'
                    : null
              : null,
        ),
        if (values.length > 1) ...[
          const SizedBox(height: 7),
          Wrap(
            key: Key('${fieldKey.toString()}-chips'),
            spacing: 6,
            runSpacing: 5,
            children: [
              for (final value in values)
                InputChip(
                  label: Text(value),
                  onDeleted: () {
                    final remaining = [...values]..remove(value);
                    controller.text = remaining.join(', ');
                    controller.selection = TextSelection.collapsed(
                      offset: controller.text.length,
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
