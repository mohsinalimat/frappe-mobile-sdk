// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

/// A single auto-calc rule extracted from a client script.
///
/// Represents a `frm.set_value('targetField', expression)` call found inside
/// a field handler.
class CalcRule {
  final String targetField;
  final String expression;
  const CalcRule({required this.targetField, required this.expression});

  @override
  String toString() => 'CalcRule($targetField = $expression)';

  @override
  bool operator ==(Object other) =>
      other is CalcRule &&
      other.targetField == targetField &&
      other.expression == expression;

  @override
  int get hashCode => targetField.hashCode ^ expression.hashCode;
}

/// Parses Frappe client scripts (`__js`) to extract `frm.set_value()` auto-calc
/// rules grouped by their trigger field.
///
/// Handles two handler syntaxes:
/// ```js
/// frappe.ui.form.on('DocType', {
///   fieldname(frm) { ... }       // shorthand
///   fieldname: function(frm) { ... }  // function keyword
/// });
/// ```
class ClientScriptParser {
  // Handlers that are lifecycle hooks, not field triggers.
  static const _nonFieldHandlers = {
    'refresh',
    'validate',
    'onload',
    'before_save',
    'after_save',
    'on_submit',
    'before_submit',
  };

  // Matches: fieldname(frm) { body }  OR  fieldname: function(frm) { body }
  // Captures: group 1 = fieldname, group 2 = handler body
  static final _handlerRe = RegExp(
    r'(\w+)\s*(?:\(frm\)|:\s*function\s*\(frm\))\s*\{',
  );

  // Matches: frm.set_value('target', expression)  or  frm.set_value("target", expression)
  static final _setValueRe = RegExp(
    r'''frm\.set_value\(\s*['"](\w+)['"]\s*,\s*(.+?)\s*\)''',
  );

  // Matches: var x = expression;  or  let x = expression;  or  const x = expression;
  static final _varAssignRe = RegExp(
    r'(?:var|let|const)\s+(\w+)\s*=\s*(.+?)\s*;',
  );

  /// Parses a client script and returns a map from trigger fieldname to
  /// the list of [CalcRule]s that should fire when that field changes.
  ///
  /// Returns an empty map for null, empty, or fully-commented scripts.
  static Map<String, List<CalcRule>> parse(String? js) {
    if (js == null || js.trim().isEmpty) return {};

    // Strip single-line comments but preserve strings
    final stripped = _stripComments(js);
    if (stripped.trim().isEmpty) return {};

    final result = <String, List<CalcRule>>{};

    for (final handlerMatch in _handlerRe.allMatches(stripped)) {
      final fieldname = handlerMatch.group(1)!;
      if (_nonFieldHandlers.contains(fieldname)) continue;

      // Extract the body by finding the matching closing brace
      final bodyStart = handlerMatch.end;
      final body = _extractBody(stripped, bodyStart);
      if (body == null) continue;

      // Collect var assignments for resolution
      final vars = <String, String>{};
      for (final varMatch in _varAssignRe.allMatches(body)) {
        vars[varMatch.group(1)!] = varMatch.group(2)!.trim();
      }

      // Find all frm.set_value calls
      final rules = <CalcRule>[];
      for (final svMatch in _setValueRe.allMatches(body)) {
        final target = svMatch.group(1)!;
        var expression = svMatch.group(2)!.trim();

        // Resolve simple var references
        if (vars.containsKey(expression)) {
          expression = vars[expression]!;
        }

        rules.add(CalcRule(targetField: target, expression: expression));
      }

      if (rules.isNotEmpty) {
        result.putIfAbsent(fieldname, () => []).addAll(rules);
      }
    }

    return result;
  }

  /// Returns the set of all target fieldnames (fields written to by set_value).
  static Set<String> targetFieldnames(String? js) {
    final parsed = parse(js);
    final targets = <String>{};
    for (final rules in parsed.values) {
      for (final rule in rules) {
        targets.add(rule.targetField);
      }
    }
    return targets;
  }

  /// Extract balanced-brace body starting at [start] (which points just after
  /// the opening `{`).
  static String? _extractBody(String source, int start) {
    int depth = 1;
    int i = start;
    while (i < source.length && depth > 0) {
      final ch = source[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
      }
      i++;
    }
    if (depth != 0) return null;
    // Return content between opening { and closing }
    return source.substring(start, i - 1);
  }

  /// Strip single-line JS comments (// ...) while preserving quoted strings.
  static String _stripComments(String js) {
    final buf = StringBuffer();
    int i = 0;
    while (i < js.length) {
      // Skip string literals
      if (js[i] == "'" || js[i] == '"') {
        final quote = js[i];
        buf.write(quote);
        i++;
        while (i < js.length && js[i] != quote) {
          if (js[i] == '\\' && i + 1 < js.length) {
            buf.write(js[i]);
            buf.write(js[i + 1]);
            i += 2;
          } else {
            buf.write(js[i]);
            i++;
          }
        }
        if (i < js.length) {
          buf.write(js[i]); // closing quote
          i++;
        }
      } else if (i + 1 < js.length && js[i] == '/' && js[i + 1] == '/') {
        // Single-line comment — skip to end of line
        while (i < js.length && js[i] != '\n') {
          i++;
        }
      } else if (i + 1 < js.length && js[i] == '/' && js[i + 1] == '*') {
        // Block comment — skip to */
        i += 2;
        while (i + 1 < js.length && !(js[i] == '*' && js[i + 1] == '/')) {
          i++;
        }
        if (i + 1 < js.length) i += 2; // skip */
      } else {
        buf.write(js[i]);
        i++;
      }
    }
    return buf.toString();
  }
}
