import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/course_notes.dart';
import 'package:sprache/src/domain/language.dart';

void main() {
  test('every supported language has a complete six-unit note set', () {
    for (final language in LanguageTag.values) {
      for (var unitIndex = 0; unitIndex < 6; unitIndex++) {
        final note = courseNoteFor(language, unitIndex);

        expect(
          note.title,
          isNotEmpty,
          reason: '${language.code} unit $unitIndex',
        );
        expect(
          note.pattern,
          isNotEmpty,
          reason: '${language.code} unit $unitIndex',
        );
        expect(
          note.patternMeaning,
          isNotEmpty,
          reason: '${language.code} unit $unitIndex',
        );
        expect(
          note.examples,
          hasLength(2),
          reason: '${language.code} unit $unitIndex',
        );
        expect(
          note.examples.every(
            (example) => example.target.isNotEmpty && example.korean.isNotEmpty,
          ),
          isTrue,
        );
        expect(note.usageTip, isNotEmpty);
        expect(note.soundTip, isNotEmpty);
      }
    }
  });

  test('invalid unit indexes are rejected', () {
    expect(() => courseNoteFor(LanguageTag.english, 6), throwsRangeError);
  });
}
