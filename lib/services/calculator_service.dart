/// Offline arithmetic calculator. Understands both symbols (+ - * / ^ ()) and
/// spoken German operator words (plus, minus, mal, durch, hoch), so voice
/// input like "rechne 12 mal 7" and typed input like "5 * (3 + 2)" both work.
class CalculatorService {
  static final _wordReplacements = <RegExp, String>{
    RegExp(r'\bplus\b'): '+',
    RegExp(r'\bminus\b'): '-',
    RegExp(r'\bgeteilt durch\b'): '/',
    RegExp(r'\bdurch\b'): '/',
    RegExp(r'\bmal\b'): '*',
    RegExp(r'\bhoch\b'): '^',
  };

  static String _normalize(String input) {
    var text = input.toLowerCase();
    for (final entry in _wordReplacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text.replaceAll(',', '.');
  }

  /// True if [input], after normalizing operator words, only contains
  /// characters that could be part of an arithmetic expression and at
  /// least one digit. Used to decide whether e.g. "was ist 5 plus 3" should
  /// go to the calculator instead of the Wikipedia lookup.
  static bool looksLikeExpression(String input) {
    final normalized = _normalize(input).trim();
    if (normalized.isEmpty) return false;
    if (!RegExp(r'\d').hasMatch(normalized)) return false;
    return RegExp(r'^[0-9+\-*/^().\s]+$').hasMatch(normalized);
  }

  /// Evaluates [input], returning null if it isn't a valid expression
  /// (including division by zero and unbalanced parentheses).
  static double? evaluate(String input) {
    final normalized = _normalize(input);
    try {
      final parser = _Parser(normalized);
      final value = parser.parseExpression();
      parser.skipSpaces();
      if (!parser.atEnd) return null;
      return value;
    } on FormatException {
      return null;
    }
  }

  /// Formats a result without a trailing ".0" for whole numbers, and
  /// without excessive floating-point noise otherwise.
  static String format(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    final rounded = (value * 1e6).round() / 1e6;
    var text = rounded.toString();
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }
}

/// Small recursive-descent parser/evaluator for `+ - * / ^ ( )` with the
/// usual precedence, right-associative `^`, and unary `+`/`-`.
class _Parser {
  _Parser(this._text) : _pos = 0;

  final String _text;
  int _pos;

  bool get atEnd => _pos >= _text.length;

  void skipSpaces() {
    while (!atEnd && _text[_pos] == ' ') {
      _pos++;
    }
  }

  String? _peek() => atEnd ? null : _text[_pos];

  double parseExpression() {
    var value = _parseTerm();
    skipSpaces();
    while (!atEnd && (_peek() == '+' || _peek() == '-')) {
      final op = _text[_pos++];
      final rhs = _parseTerm();
      value = op == '+' ? value + rhs : value - rhs;
      skipSpaces();
    }
    return value;
  }

  double _parseTerm() {
    var value = _parsePower();
    skipSpaces();
    while (!atEnd && (_peek() == '*' || _peek() == '/')) {
      final op = _text[_pos++];
      final rhs = _parsePower();
      if (op == '*') {
        value = value * rhs;
      } else {
        if (rhs == 0) throw const FormatException('division by zero');
        value = value / rhs;
      }
      skipSpaces();
    }
    return value;
  }

  double _parsePower() {
    final value = _parseUnary();
    skipSpaces();
    if (!atEnd && _peek() == '^') {
      _pos++;
      final exponent = _parsePower(); // right-associative
      return _pow(value, exponent);
    }
    return value;
  }

  double _pow(double base, double exponent) {
    if (exponent != exponent.roundToDouble()) {
      throw const FormatException('only whole-number exponents supported');
    }
    var result = 1.0;
    final steps = exponent.abs().round();
    for (var i = 0; i < steps; i++) {
      result *= base;
    }
    return exponent < 0 ? 1 / result : result;
  }

  double _parseUnary() {
    skipSpaces();
    if (!atEnd && _peek() == '-') {
      _pos++;
      return -_parseUnary();
    }
    if (!atEnd && _peek() == '+') {
      _pos++;
      return _parseUnary();
    }
    return _parseAtom();
  }

  double _parseAtom() {
    skipSpaces();
    if (!atEnd && _peek() == '(') {
      _pos++;
      final value = parseExpression();
      skipSpaces();
      if (atEnd || _peek() != ')') throw const FormatException('missing )');
      _pos++;
      return value;
    }
    final start = _pos;
    while (!atEnd && RegExp(r'[0-9.]').hasMatch(_text[_pos])) {
      _pos++;
    }
    if (_pos == start) throw const FormatException('expected number');
    return double.parse(_text.substring(start, _pos));
  }
}
