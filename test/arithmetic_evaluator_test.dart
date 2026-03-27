import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/src/utils/arithmetic_evaluator.dart';

void main() {
  group('ArithmeticEvaluator', () {
    // ── Simple arithmetic ──────────────────────────────────────────────

    test('simple addition', () {
      expect(ArithmeticEvaluator.evaluate('2 + 3', {}), equals(5.0));
    });

    test('simple subtraction', () {
      expect(ArithmeticEvaluator.evaluate('10 - 4', {}), equals(6.0));
    });

    test('simple multiplication', () {
      expect(ArithmeticEvaluator.evaluate('3 * 7', {}), equals(21.0));
    });

    test('simple division', () {
      expect(ArithmeticEvaluator.evaluate('20 / 4', {}), equals(5.0));
    });

    test('operator precedence: multiplication before addition', () {
      expect(ArithmeticEvaluator.evaluate('2 + 3 * 4', {}), equals(14.0));
    });

    test('negative result', () {
      expect(ArithmeticEvaluator.evaluate('3 - 10', {}), equals(-7.0));
    });

    // ── Parentheses ────────────────────────────────────────────────────

    test('parentheses override precedence', () {
      expect(ArithmeticEvaluator.evaluate('(2 + 3) * 4', {}), equals(20.0));
    });

    test('nested parentheses', () {
      expect(
        ArithmeticEvaluator.evaluate('((2 + 3) * (4 - 1))', {}),
        equals(15.0),
      );
    });

    // ── Field references ───────────────────────────────────────────────

    test('frm.doc.fieldname resolves from formData', () {
      expect(
        ArithmeticEvaluator.evaluate(
          'frm.doc.qty * frm.doc.rate',
          {'qty': 5, 'rate': 100},
        ),
        equals(500.0),
      );
    });

    test('doc.fieldname resolves from formData', () {
      expect(
        ArithmeticEvaluator.evaluate(
          'doc.qty + doc.rate',
          {'qty': 10, 'rate': 20},
        ),
        equals(30.0),
      );
    });

    test('mixed frm.doc and doc references', () {
      expect(
        ArithmeticEvaluator.evaluate(
          'frm.doc.a + doc.b',
          {'a': 3, 'b': 7},
        ),
        equals(10.0),
      );
    });

    // ── Missing / null fields ──────────────────────────────────────────

    test('missing field resolves to 0', () {
      expect(
        ArithmeticEvaluator.evaluate('frm.doc.missing + 5', {}),
        equals(5.0),
      );
    });

    test('null formData value resolves to 0', () {
      expect(
        ArithmeticEvaluator.evaluate('doc.x + 1', {'x': null}),
        equals(1.0),
      );
    });

    // ── String numeric values ──────────────────────────────────────────

    test('string numeric values parsed to double', () {
      expect(
        ArithmeticEvaluator.evaluate('doc.price * doc.qty', {
          'price': '12.5',
          'qty': '4',
        }),
        equals(50.0),
      );
    });

    test('non-numeric string resolves to 0', () {
      expect(
        ArithmeticEvaluator.evaluate('doc.x + 1', {'x': 'abc'}),
        equals(1.0),
      );
    });

    // ── Division by zero ───────────────────────────────────────────────

    test('division by zero returns 0', () {
      expect(ArithmeticEvaluator.evaluate('10 / 0', {}), equals(0.0));
    });

    test('division by zero field returns 0', () {
      expect(
        ArithmeticEvaluator.evaluate('doc.a / doc.b', {'a': 100, 'b': 0}),
        equals(0.0),
      );
    });

    // ── Fallback operator (||) ─────────────────────────────────────────

    test('fallback: left is 0, uses right', () {
      expect(ArithmeticEvaluator.evaluate('0 || 1', {}), equals(1.0));
    });

    test('fallback: left is non-zero, keeps left', () {
      expect(ArithmeticEvaluator.evaluate('5 || 1', {}), equals(5.0));
    });

    test('fallback: missing field falls back', () {
      expect(
        ArithmeticEvaluator.evaluate('doc.missing || 42', {}),
        equals(42.0),
      );
    });

    // ── Null / empty expression ────────────────────────────────────────

    test('null expression returns 0', () {
      expect(ArithmeticEvaluator.evaluate(null, {}), equals(0.0));
    });

    test('empty expression returns 0', () {
      expect(ArithmeticEvaluator.evaluate('', {}), equals(0.0));
    });

    test('whitespace-only expression returns 0', () {
      expect(ArithmeticEvaluator.evaluate('   ', {}), equals(0.0));
    });

    // ── Real-world formulas ────────────────────────────────────────────

    test('livestock total: sum of 5 fields', () {
      final data = {
        'cows': 10,
        'buffaloes': 5,
        'goats': 20,
        'poultry': 50,
        'other': 3,
      };
      final expr =
          'doc.cows + doc.buffaloes + doc.goats + doc.poultry + doc.other';
      expect(ArithmeticEvaluator.evaluate(expr, data), equals(88.0));
    });

    test('price sold at: value * 100000 / volume', () {
      final data = {'value_in_lakhs': 2.5, 'volume_kg': 500};
      final expr = 'doc.value_in_lakhs * 100000 / doc.volume_kg';
      expect(ArithmeticEvaluator.evaluate(expr, data), equals(500.0));
    });

    test('price sold at: volume zero → 0 (no crash)', () {
      final data = {'value_in_lakhs': 2.5, 'volume_kg': 0};
      final expr = 'doc.value_in_lakhs * 100000 / doc.volume_kg';
      expect(ArithmeticEvaluator.evaluate(expr, data), equals(0.0));
    });

    test('incremental benefit: complex nested expression', () {
      // (income_with - cost_with) - (income_without - cost_without)
      final data = {
        'income_with': 50000,
        'cost_with': 30000,
        'income_without': 35000,
        'cost_without': 25000,
      };
      final expr =
          '(doc.income_with - doc.cost_with) - (doc.income_without - doc.cost_without)';
      // (50000 - 30000) - (35000 - 25000) = 20000 - 10000 = 10000
      expect(ArithmeticEvaluator.evaluate(expr, data), equals(10000.0));
    });

    test('decimal precision maintained', () {
      expect(
        ArithmeticEvaluator.evaluate('1.5 + 2.3', {}),
        closeTo(3.8, 0.0001),
      );
    });
  });
}
