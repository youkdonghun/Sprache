import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/services/clipboard_read_session.dart';

void main() {
  test('claims the explicit clipboard read before awaiting it', () async {
    final session = ClipboardReadSession();
    var reads = 0;

    final first = session.readOnce(() async {
      reads++;
      await Future<void>.delayed(Duration.zero);
      return 'private draft';
    });
    final second = await session.readOnce(() async {
      reads++;
      return 'must not be read';
    });

    expect(second.status, ClipboardReadStatus.alreadyRead);
    expect((await first).text, 'private draft');
    expect(reads, 1);
    expect(session.hasUnconfirmedContent, isTrue);
  });

  test(
    'confirmation and discard release unconfirmed clipboard state',
    () async {
      final confirmed = ClipboardReadSession();
      await confirmed.readOnce(() async => 'confirmed');
      confirmed.confirm();
      expect(confirmed.hasUnconfirmedContent, isFalse);

      final discarded = ClipboardReadSession();
      await discarded.readOnce(() async => 'discarded');
      discarded.discard();
      expect(discarded.hasUnconfirmedContent, isFalse);
    },
  );

  test('empty and failed reads are consumed without retaining text', () async {
    final empty = ClipboardReadSession();
    expect(
      (await empty.readOnce(() async => '  ')).status,
      ClipboardReadStatus.empty,
    );
    expect(empty.hasUnconfirmedContent, isFalse);

    final failed = ClipboardReadSession();
    expect(
      (await failed.readOnce(() async => throw StateError('denied'))).status,
      ClipboardReadStatus.failed,
    );
    expect(failed.hasUnconfirmedContent, isFalse);
  });
}
