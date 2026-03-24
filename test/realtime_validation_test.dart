// test/realtime_validation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/frappe_mobile_sdk.dart';

void main() {
  group('FrappeFormBuilder — real-time validation', () {
    testWidgets('fieldValidator fires inline on field change', (tester) async {
      String? capturedField;
      dynamic capturedValue;

      final meta = DocTypeMeta(
        name: 'Test',
        fields: [
          DocField(fieldname: 'city', fieldtype: 'Data', label: 'City'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FrappeFormBuilder(
            meta: meta,
            fieldValidator: (fieldName, value, formData) {
              capturedField = fieldName;
              capturedValue = value;
              if (value?.toString() == 'bad') return 'Invalid city';
              return null;
            },
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField).first, 'bad');
      await tester.pumpAndSettle();

      expect(capturedField, 'city');
      expect(capturedValue, 'bad');
      expect(find.text('Invalid city'), findsOneWidget);
    });

    testWidgets('reqd error appears inline without submit', (tester) async {
      final meta = DocTypeMeta(
        name: 'Test',
        fields: [
          DocField(
            fieldname: 'name',
            fieldtype: 'Data',
            label: 'Name',
            reqd: true,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FrappeFormBuilder(meta: meta),
        ),
      ));

      // Interact then clear the field to trigger onUserInteraction
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('readOnly fields do not trigger fieldValidator', (tester) async {
      int callCount = 0;

      final meta = DocTypeMeta(
        name: 'Test',
        fields: [
          DocField(
            fieldname: 'locked',
            fieldtype: 'Data',
            label: 'Locked',
            readOnly: true,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FrappeFormBuilder(
            meta: meta,
            fieldValidator: (fieldName, value, formData) {
              callCount++;
              return null;
            },
          ),
        ),
      ));

      await tester.pump();
      expect(callCount, 0);
    });

    testWidgets('fieldValidator receives full formData snapshot', (tester) async {
      Map<String, dynamic>? receivedFormData;

      final meta = DocTypeMeta(
        name: 'Test',
        fields: [
          DocField(fieldname: 'a', fieldtype: 'Data', label: 'A'),
          DocField(fieldname: 'b', fieldtype: 'Data', label: 'B'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FrappeFormBuilder(
            meta: meta,
            initialData: {'a': 'hello'},
            fieldValidator: (fieldName, value, formData) {
              if (fieldName == 'b') receivedFormData = formData;
              return null;
            },
          ),
        ),
      ));

      // Type in field B; formData snapshot must include field A's value
      await tester.enterText(find.byType(TextField).last, 'world');
      await tester.pump();

      expect(receivedFormData, isNotNull);
      expect(receivedFormData!['a'], 'hello');
    });
  });
}
