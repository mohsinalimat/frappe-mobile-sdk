import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/src/utils/client_script_parser.dart';

void main() {
  group('ClientScriptParser', () {
    group('parse()', () {
      test('basic frm.set_value parsing', () {
        const js = '''
frappe.ui.form.on('My DocType', {
  quantity(frm) {
    frm.set_value('total', frm.doc.quantity * frm.doc.rate);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result, contains('quantity'));
        expect(result['quantity'], hasLength(1));
        expect(result['quantity']![0].targetField, 'total');
        expect(result['quantity']![0].expression,
            'frm.doc.quantity * frm.doc.rate');
      });

      test('multiple set_value in one handler', () {
        const js = '''
frappe.ui.form.on('Sales', {
  discount(frm) {
    frm.set_value('net_total', frm.doc.gross - frm.doc.discount);
    frm.set_value('tax', frm.doc.net_total * 0.18);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result['discount'], hasLength(2));
        expect(result['discount']![0].targetField, 'net_total');
        expect(result['discount']![1].targetField, 'tax');
      });

      test('function keyword syntax', () {
        const js = '''
frappe.ui.form.on('Invoice', {
  amount: function(frm) {
    frm.set_value('grand_total', frm.doc.amount + frm.doc.tax);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result, contains('amount'));
        expect(result['amount']![0].targetField, 'grand_total');
        expect(result['amount']![0].expression,
            'frm.doc.amount + frm.doc.tax');
      });

      test('skips non-field handlers (refresh, validate, etc.)', () {
        const js = '''
frappe.ui.form.on('Test', {
  refresh(frm) {
    frm.set_value('hidden', 1);
  },
  validate(frm) {
    frm.set_value('status', 'Validated');
  },
  qty(frm) {
    frm.set_value('total', frm.doc.qty * frm.doc.rate);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result.containsKey('refresh'), false);
        expect(result.containsKey('validate'), false);
        expect(result, contains('qty'));
      });

      test('empty script returns empty map', () {
        expect(ClientScriptParser.parse(''), isEmpty);
        expect(ClientScriptParser.parse('   '), isEmpty);
      });

      test('null script returns empty map', () {
        expect(ClientScriptParser.parse(null), isEmpty);
      });

      test('fully commented script returns empty map', () {
        const js = '''
// frappe.ui.form.on('Test', {
//   qty(frm) {
//     frm.set_value('total', frm.doc.qty * 2);
//   }
// });
''';
        final result = ClientScriptParser.parse(js);
        expect(result, isEmpty);
      });

      test('var assignment before set_value resolves expression', () {
        const js = '''
frappe.ui.form.on('Calc', {
  price(frm) {
    var computed = frm.doc.price * frm.doc.quantity;
    frm.set_value('total_amount', computed);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result['price']![0].targetField, 'total_amount');
        expect(result['price']![0].expression,
            'frm.doc.price * frm.doc.quantity');
      });

      test('double quotes in set_value', () {
        const js = '''
frappe.ui.form.on('Test', {
  rate(frm) {
    frm.set_value("amount", frm.doc.rate * frm.doc.qty);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result['rate']![0].targetField, 'amount');
      });

      test('multiple handlers in one script', () {
        const js = '''
frappe.ui.form.on('Order', {
  qty(frm) {
    frm.set_value('total', frm.doc.qty * frm.doc.rate);
  },
  rate(frm) {
    frm.set_value('total', frm.doc.qty * frm.doc.rate);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result, contains('qty'));
        expect(result, contains('rate'));
        expect(result.keys, hasLength(2));
      });

      test('let and const variable assignments also resolve', () {
        const js = '''
frappe.ui.form.on('Calc', {
  width(frm) {
    let area = frm.doc.width * frm.doc.height;
    frm.set_value('area_field', area);
  }
});
''';
        final result = ClientScriptParser.parse(js);
        expect(result['width']![0].expression,
            'frm.doc.width * frm.doc.height');
      });
    });

    group('targetFieldnames()', () {
      test('returns set of all target fields', () {
        const js = '''
frappe.ui.form.on('Order', {
  qty(frm) {
    frm.set_value('total', frm.doc.qty * frm.doc.rate);
    frm.set_value('gst', frm.doc.total * 0.18);
  },
  discount(frm) {
    frm.set_value('net', frm.doc.total - frm.doc.discount);
  }
});
''';
        final targets = ClientScriptParser.targetFieldnames(js);
        expect(targets, {'total', 'gst', 'net'});
      });

      test('returns empty set for null', () {
        expect(ClientScriptParser.targetFieldnames(null), isEmpty);
      });
    });
  });
}
