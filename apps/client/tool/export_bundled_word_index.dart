import 'dart:convert';
import 'dart:io';

import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');
  final repositoryRoot = Directory.current.parent.parent;
  final output = File(
    '${repositoryRoot.path}${Platform.pathSeparator}language-packs'
    '${Platform.pathSeparator}sources${Platform.pathSeparator}'
    'bundled-word-terms.json',
  );
  final languages = <String, List<String>>{};
  for (final language in LanguageTag.values.where(
    (value) => value != LanguageTag.korean,
  )) {
    final words = sampleContent
        .where(
          (item) =>
              item.learningLanguage == language &&
              item.kind == LearningItemKind.word,
        )
        .map((item) => item.text)
        .toList(growable: false);
    if (words.length != 80) {
      throw StateError(
        '${language.code} bundled word count is ${words.length}',
      );
    }
    languages[language.code] = words;
  }
  final expected =
      '${const JsonEncoder.withIndent('  ').convert({'schemaVersion': 1, 'generatedFrom': 'apps/client/lib/src/data/sample_content.dart', 'languages': languages})}\n';

  if (checkOnly) {
    if (!output.existsSync() || output.readAsStringSync() != expected) {
      stderr.writeln('bundled-word-terms.json is out of date.');
      exitCode = 1;
    }
    return;
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(expected);
  stdout.writeln('Updated ${output.path}');
}
