enum ClipboardReadStatus { accepted, empty, alreadyRead, failed }

class ClipboardReadResult {
  const ClipboardReadResult._(this.status, this.text);

  const ClipboardReadResult.accepted(String text)
    : this._(ClipboardReadStatus.accepted, text);

  const ClipboardReadResult.empty() : this._(ClipboardReadStatus.empty, null);

  const ClipboardReadResult.alreadyRead()
    : this._(ClipboardReadStatus.alreadyRead, null);

  const ClipboardReadResult.failed() : this._(ClipboardReadStatus.failed, null);

  final ClipboardReadStatus status;
  final String? text;
}

typedef ClipboardTextReader = Future<String?> Function();

/// Keeps clipboard access explicit, one-shot, and scoped to one UI surface.
///
/// The session deliberately retains no clipboard text after confirmation or
/// discard. Widgets should also clear any text controller that received the
/// value when an unconfirmed session is disposed.
class ClipboardReadSession {
  bool _hasRead = false;
  bool _hasUnconfirmedContent = false;

  bool get hasRead => _hasRead;
  bool get hasUnconfirmedContent => _hasUnconfirmedContent;

  Future<ClipboardReadResult> readOnce(ClipboardTextReader reader) async {
    if (_hasRead) return const ClipboardReadResult.alreadyRead();

    // Claim the read before awaiting the platform channel so rapid double
    // taps cannot start two concurrent clipboard reads.
    _hasRead = true;
    try {
      final text = await reader();
      if (text == null || text.trim().isEmpty) {
        return const ClipboardReadResult.empty();
      }
      _hasUnconfirmedContent = true;
      return ClipboardReadResult.accepted(text);
    } on Object {
      return const ClipboardReadResult.failed();
    }
  }

  void confirm() {
    _hasUnconfirmedContent = false;
  }

  void discard() {
    _hasUnconfirmedContent = false;
  }
}
