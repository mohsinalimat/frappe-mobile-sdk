// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

/// Evaluates Frappe depends_on expressions
class DependsOnEvaluator {
  /// Evaluate depends_on expression
  /// Supports: eval:doc.field == value, eval:doc.field != value, etc.
  static bool evaluate(String? expression, Map<String, dynamic> formData) {
    if (expression == null || expression.isEmpty) return true;

    // Remove eval: prefix if present
    String expr = expression.trim();
    if (expr.startsWith('eval:')) {
      expr = expr.substring(5).trim();
    }

    // Normalize JavaScript strict equality/inequality to the double-operator form
    // that the parser below understands. Handles both spaced (=== ) and
    // unspaced (===) variants, e.g. Frappe depends_on: eval:doc.field === 'Other'.
    expr = expr.replaceAll('!==', ' != ').replaceAll('===', ' == ');

    try {
      // Handle && (AND) operator — MUST be checked before simple operators so
      // compound expressions like "doc.a == 'X' && doc.b > 0" are split first.
      if (expr.contains(' && ')) {
        final parts = expr.split(' && ');
        return parts.every((part) => evaluate(part.trim(), formData));
      }

      // Handle || (OR) operator — same priority reason as &&.
      if (expr.contains(' || ')) {
        final parts = expr.split(' || ');
        return parts.any((part) => evaluate(part.trim(), formData));
      }

      // Handle Array.some() pattern:
      // (doc.FIELD||[]).some(r=>r.CHILD_FIELD == 'VALUE')
      final someMatch = RegExp(
        r'^\(doc\.(\w+)\|\|\[\]\)\.some\(r=>r\.(\w+)\s*==\s*[\'"](.+?)[\'"]\)$',
      ).firstMatch(expr);
      if (someMatch != null) {
        final fieldName = someMatch.group(1)!;
        final childField = someMatch.group(2)!;
        final targetValue = someMatch.group(3)!;
        final fieldValue = formData[fieldName];
        if (fieldValue is List) {
          return fieldValue.any((item) {
            if (item is Map) {
              return item[childField]?.toString() == targetValue;
            }
            return false;
          });
        }
        return false;
      }

      // Simple evaluation for common patterns
      // eval:doc.field == value
      // eval:doc.field != value
      // eval:doc.field > value
      // eval:doc.field < value
      // eval:doc.field >= value
      // eval:doc.field <= value

      // Handle == comparison
      if (expr.contains(' == ')) {
        final parts = expr.split(' == ');
        if (parts.length == 2) {
          final fieldName = _extractFieldName(parts[0]);
          final expectedValue = _extractValue(parts[1]);
          final actualValue = formData[fieldName];
          return _compareValues(actualValue, expectedValue, '==');
        }
      }

      // Handle != comparison
      if (expr.contains(' != ')) {
        final parts = expr.split(' != ');
        if (parts.length == 2) {
          final fieldName = _extractFieldName(parts[0]);
          final expectedValue = _extractValue(parts[1]);
          final actualValue = formData[fieldName];
          return _compareValues(actualValue, expectedValue, '!=');
        }
      }

      // Handle >= comparison (before > to avoid partial match)
      if (expr.contains(' >= ')) {
        final parts = expr.split(' >= ');
        if (parts.length == 2) {
          final fieldName = _extractFieldName(parts[0]);
          final expectedValue = _extractValue(parts[1]);
          final actualValue = formData[fieldName];
          return _compareValues(actualValue, expectedValue, '>=');
        }
      }

      // Handle <= comparison (before < to avoid partial match)
      if (expr.contains(' <= ')) {
        final parts = expr.split(' <= ');
        if (parts.length == 2) {
          final fieldName = _extractFieldName(parts[0]);
          final expectedValue = _extractValue(parts[1]);
          final actualValue = formData[fieldName];
          return _compareValues(actualValue, expectedValue, '<=');
        }
      }

      // Handle > comparison
      if (expr.contains(' > ')) {
        final parts = expr.split(' > ');
        if (parts.length == 2) {
          final fieldName = _extractFieldName(parts[0]);
          final expectedValue = _extractValue(parts[1]);
          final actualValue = formData[fieldName];
          return _compareValues(actualValue, expectedValue, '>');
        }
      }

      // Handle < comparison
      if (expr.contains(' < ')) {
        final parts = expr.split(' < ');
        if (parts.length == 2) {
          final fieldName = _extractFieldName(parts[0]);
          final expectedValue = _extractValue(parts[1]);
          final actualValue = formData[fieldName];
          return _compareValues(actualValue, expectedValue, '<');
        }
      }

      // Default: check if field exists and is truthy
      final fieldName = _extractFieldName(expr);
      final value = formData[fieldName];
      return value != null && value != '' && value != 0 && value != false;
    } catch (e) {
      // If evaluation fails, default to true (show field)
      return true;
    }
  }

  static String _extractFieldName(String expr) {
    // Remove doc. prefix if present
    expr = expr.trim();
    if (expr.startsWith('doc.')) {
      expr = expr.substring(4).trim();
    }
    return expr;
  }

  static dynamic _extractValue(String expr) {
    expr = expr.trim();
    // Remove quotes if present
    if ((expr.startsWith('"') && expr.endsWith('"')) ||
        (expr.startsWith("'") && expr.endsWith("'"))) {
      expr = expr.substring(1, expr.length - 1);
    }
    // Try to parse as number
    if (RegExp(r'^-?\d+$').hasMatch(expr)) {
      return int.tryParse(expr);
    }
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(expr)) {
      return double.tryParse(expr);
    }
    return expr;
  }

  static bool _compareValues(
    dynamic actual,
    dynamic expected,
    String operator,
  ) {
    switch (operator) {
      case '==':
        return actual == expected;
      case '!=':
        return actual != expected;
      case '>':
        final gtA = actual is num ? actual : num.tryParse(actual?.toString() ?? '');
        final gtE = expected is num ? expected : num.tryParse(expected?.toString() ?? '');
        if (gtA != null && gtE != null) return gtA > gtE;
        return false;
      case '<':
        final ltA = actual is num ? actual : num.tryParse(actual?.toString() ?? '');
        final ltE = expected is num ? expected : num.tryParse(expected?.toString() ?? '');
        if (ltA != null && ltE != null) return ltA < ltE;
        return false;
      case '>=':
        final gteA = actual is num ? actual : num.tryParse(actual?.toString() ?? '');
        final gteE = expected is num ? expected : num.tryParse(expected?.toString() ?? '');
        if (gteA != null && gteE != null) return gteA >= gteE;
        return false;
      case '<=':
        final lteA = actual is num ? actual : num.tryParse(actual?.toString() ?? '');
        final lteE = expected is num ? expected : num.tryParse(expected?.toString() ?? '');
        if (lteA != null && lteE != null) return lteA <= lteE;
        return false;
      default:
        return false;
    }
  }
}
