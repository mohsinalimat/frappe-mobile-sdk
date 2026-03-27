// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

/// Evaluates arithmetic expressions with field references for client-script
/// auto-calc formulas. Uses a recursive descent parser supporting `+`, `-`,
/// `*`, `/`, parentheses, numeric constants, field references (`frm.doc.x`
/// or `doc.x`), and the `|| fallback` operator.
class ArithmeticEvaluator {
  final String _source;
  final Map<String, dynamic> _formData;
  int _pos = 0;

  ArithmeticEvaluator._(this._source, this._formData);

  /// Evaluate an arithmetic expression against [formData].
  ///
  /// Returns 0.0 for null/empty expressions or on any parse error.
  static double evaluate(String? expression, Map<String, dynamic> formData) {
    if (expression == null || expression.trim().isEmpty) return 0.0;

    try {
      final evaluator = ArithmeticEvaluator._(expression.trim(), formData);
      final result = evaluator._parseExpression();
      return result.isNaN || result.isInfinite ? 0.0 : result;
    } catch (_) {
      return 0.0;
    }
  }

  // ── Lexer helpers ────────────────────────────────────────────────────

  void _skipWhitespace() {
    while (_pos < _source.length && _source[_pos] == ' ') {
      _pos++;
    }
  }

  bool _match(String s) {
    _skipWhitespace();
    if (_pos + s.length <= _source.length &&
        _source.substring(_pos, _pos + s.length) == s) {
      _pos += s.length;
      return true;
    }
    return false;
  }

  bool _peek(String s) {
    _skipWhitespace();
    return _pos + s.length <= _source.length &&
        _source.substring(_pos, _pos + s.length) == s;
  }

  // ── Grammar ──────────────────────────────────────────────────────────
  // expression  = fallback
  // fallback    = additive ( '||' additive )*
  // additive    = multiplicative ( ('+' | '-') multiplicative )*
  // multiplicative = unary ( ('*' | '/') unary )*
  // unary       = '-' unary | primary
  // primary     = '(' expression ')' | number | fieldRef

  double _parseExpression() {
    final result = _parseFallback();
    return result;
  }

  /// `||` is treated as a fallback: if left is 0 or NaN, use right.
  double _parseFallback() {
    double left = _parseAdditive();
    while (_peek('||')) {
      _match('||');
      final right = _parseAdditive();
      if (left == 0.0 || left.isNaN) {
        left = right;
      }
    }
    return left;
  }

  double _parseAdditive() {
    double left = _parseMultiplicative();
    while (true) {
      _skipWhitespace();
      if (_peek('+')) {
        _match('+');
        left = left + _parseMultiplicative();
      } else if (_peek('-')) {
        // Disambiguate: '-' followed by a digit without a preceding operator
        // could be a negative number inside a sub-expression. We treat it as
        // subtraction here since we are already past a primary.
        _match('-');
        left = left - _parseMultiplicative();
      } else {
        break;
      }
    }
    return left;
  }

  double _parseMultiplicative() {
    double left = _parseUnary();
    while (true) {
      _skipWhitespace();
      if (_peek('*')) {
        _match('*');
        left = left * _parseUnary();
      } else if (_peek('/')) {
        _match('/');
        final right = _parseUnary();
        if (right == 0.0) return 0.0; // division by zero → 0
        left = left / right;
      } else {
        break;
      }
    }
    return left;
  }

  double _parseUnary() {
    _skipWhitespace();
    if (_peek('-')) {
      _match('-');
      return -_parseUnary();
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipWhitespace();

    // Parenthesised sub-expression
    if (_match('(')) {
      final value = _parseExpression();
      _match(')'); // consume closing paren (tolerant if missing)
      return value;
    }

    // Field reference: frm.doc.fieldname or doc.fieldname
    if (_peek('frm.doc.') || _peek('doc.')) {
      return _parseFieldRef();
    }

    // Numeric literal
    return _parseNumber();
  }

  double _parseFieldRef() {
    _skipWhitespace();
    final start = _pos;

    // Advance past the prefix
    if (_source.substring(_pos).startsWith('frm.doc.')) {
      _pos += 8; // 'frm.doc.'
    } else if (_source.substring(_pos).startsWith('doc.')) {
      _pos += 4; // 'doc.'
    }

    // Read field name (alphanumeric + underscore)
    final nameStart = _pos;
    while (_pos < _source.length &&
        (RegExp(r'[a-zA-Z0-9_]').hasMatch(_source[_pos]))) {
      _pos++;
    }

    if (_pos == nameStart) {
      // No field name found — treat as 0
      return 0.0;
    }

    final fieldName = _source.substring(nameStart, _pos);
    return _resolveField(fieldName);
  }

  double _resolveField(String fieldName) {
    final value = _formData[fieldName];
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  double _parseNumber() {
    _skipWhitespace();
    final start = _pos;

    // Optional leading minus is handled by _parseUnary, but handle it here
    // too for robustness.
    if (_pos < _source.length && _source[_pos] == '-') _pos++;

    // Integer part
    while (_pos < _source.length && RegExp(r'[0-9]').hasMatch(_source[_pos])) {
      _pos++;
    }

    // Decimal part
    if (_pos < _source.length && _source[_pos] == '.') {
      _pos++;
      while (
          _pos < _source.length && RegExp(r'[0-9]').hasMatch(_source[_pos])) {
        _pos++;
      }
    }

    if (_pos == start) {
      throw FormatException('Expected number at position $_pos');
    }

    return double.parse(_source.substring(start, _pos));
  }
}
