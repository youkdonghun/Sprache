import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/command_palette.dart';

void main() {
  test('finds storage settings through Korean and English aliases', () {
    expect(searchCommandPalette('구글 드라이브').first.id, 'storage-settings');
    expect(searchCommandPalette('local folder').first.id, 'storage-settings');
  });

  test('ranks exact navigation commands before loose description matches', () {
    expect(searchCommandPalette('자료실').first.id, 'library');
    expect(searchCommandPalette('학습 허브').first.id, 'learning-hub');
  });

  test('supports compact fuzzy queries for major games', () {
    expect(searchCommandPalette('mtch').first.id, 'match-sprint');
    expect(searchCommandPalette('문장 순서').first.id, 'sentence-order');
    expect(searchCommandPalette('발음').first.id, 'pronunciation');
    expect(searchCommandPalette('모의고사').first.id, 'exam-simulator');
    expect(searchCommandPalette('소리 구별').first.id, 'listening-discrimination');
  });

  test('study commands enter through the learning hub coordinator', () {
    final byId = {
      for (final command in appCommandPaletteCommands) command.id: command,
    };

    expect(
      byId['production-writing']!.practiceActivityId,
      'production-writing',
    );
    expect(
      byId['listening-discrimination']!.practiceActivityId,
      'listening-discrimination',
    );
    expect(byId['exam-simulator']!.practiceActivityId, 'exam-simulator');
    expect(byId['match-sprint']!.route, isNull);
  });

  test(
    'returns authored quick commands for an empty query and honors limit',
    () {
      final commands = searchCommandPalette('', limit: 3);

      expect(commands.map((command) => command.id), [
        'quick-add',
        'home',
        'library',
      ]);
    },
  );
}
