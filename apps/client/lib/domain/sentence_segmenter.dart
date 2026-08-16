/// Splits an assistant text stream into sentences that are safe to speak.
///
/// Chinese terminal punctuation is sufficient on its own. ASCII sentence
/// punctuation is considered stable when followed by whitespace or a newline;
/// this avoids cutting a stream in the middle of a decimal or an identifier.
class SentenceSegmenter {
  String _pending = '';

  /// Text that has arrived but has not reached a stable sentence boundary.
  String get pending => _pending.trim();

  /// Adds one arbitrary stream delta and returns only newly stable sentences.
  List<String> feed(String delta) {
    if (delta.isEmpty) return const [];
    _pending += delta;
    return _drainStableSentences();
  }

  /// Ends the current stream and returns any remaining non-empty text.
  List<String> flush() {
    final remaining = _pending.trim();
    _pending = '';
    return remaining.isEmpty ? const [] : [remaining];
  }

  List<String> _drainStableSentences() {
    final stable = <String>[];
    var sentenceStart = 0;
    var index = 0;
    while (index < _pending.length) {
      final terminalEnd = _terminalEnd(index);
      if (terminalEnd == null) {
        index += 1;
        continue;
      }
      final sentence = _pending.substring(sentenceStart, terminalEnd).trim();
      if (sentence.isNotEmpty) stable.add(sentence);
      sentenceStart = terminalEnd;
      index = terminalEnd;
    }

    if (sentenceStart > 0) {
      _pending = _pending.substring(sentenceStart).trimLeft();
    }
    return List.unmodifiable(stable);
  }

  int? _terminalEnd(int index) {
    final character = _pending[index];
    if (_isChineseTerminal(character)) {
      return _consumeClosingPunctuation(index + 1);
    }
    if (!_isAsciiTerminal(character)) return null;

    // A decimal point is not a sentence boundary.
    if (character == '.' &&
        index > 0 &&
        index + 1 < _pending.length &&
        _isDigit(_pending[index - 1]) &&
        _isDigit(_pending[index + 1])) {
      return null;
    }

    final end = _consumeClosingPunctuation(index + 1);
    if (end == _pending.length) return null;
    return _isWhitespace(_pending[end]) ? end : null;
  }

  int _consumeClosingPunctuation(int end) {
    while (end < _pending.length && _isClosingPunctuation(_pending[end])) {
      end += 1;
    }
    return end;
  }

  bool _isChineseTerminal(String character) => switch (character) {
    '。' || '！' || '？' => true,
    _ => false,
  };

  bool _isAsciiTerminal(String character) => switch (character) {
    '.' || '!' || '?' => true,
    _ => false,
  };

  bool _isClosingPunctuation(String character) => switch (character) {
    '"' ||
    "'" ||
    ')' ||
    ']' ||
    '}' ||
    '»' ||
    '”' ||
    '’' ||
    '》' ||
    '）' ||
    '］' ||
    '｝' => true,
    _ => false,
  };

  bool _isWhitespace(String character) =>
      character == ' ' ||
      character == '\n' ||
      character == '\r' ||
      character == '\t';

  bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57;
}
