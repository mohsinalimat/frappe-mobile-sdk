import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frappe_mobile_sdk/frappe_mobile_sdk.dart';
import 'package:frappe_mobile_sdk/src/database/entities/link_option_entity.dart';
import 'package:frappe_mobile_sdk/src/services/link_option_service.dart';

/// Fake LinkOptionService that returns canned options without needing a FrappeClient.
class FakeLinkOptionService extends LinkOptionService {
  final List<LinkOptionEntity> _options;

  FakeLinkOptionService(this._options) : super(_createDummyClient());

  static FrappeClient _createDummyClient() => FrappeClient('http://fake');

  @override
  Future<List<LinkOptionEntity>> getLinkOptions(
    String doctype, {
    bool forceRefresh = false,
    List<List<dynamic>>? filters,
  }) async {
    return _options;
  }
}

/// Helper to build the child DocType meta that TableMultiSelectField expects.
DocTypeMeta _childMeta({
  String name = 'Loan Source Option',
  String linkFieldName = 'loan_source',
  String linkTarget = 'Loan Source',
}) {
  return DocTypeMeta(
    name: name,
    fields: [
      DocField(
        fieldname: linkFieldName,
        fieldtype: 'Link',
        label: linkFieldName,
        options: linkTarget,
      ),
    ],
    isTable: true,
  );
}

/// Standard set of link options used across tests.
List<LinkOptionEntity> _standardOptions() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    LinkOptionEntity(doctype: 'Loan Source', name: 'SHG', label: 'SHG', lastUpdated: now),
    LinkOptionEntity(doctype: 'Loan Source', name: 'Bank', label: 'Bank', lastUpdated: now),
    LinkOptionEntity(doctype: 'Loan Source', name: 'PG', label: 'PG', lastUpdated: now),
  ];
}

/// The parent DocField that uses Table MultiSelect.
DocField _parentField() {
  return DocField(
    fieldname: 'loan_sources',
    fieldtype: 'Table MultiSelect',
    label: 'Loan Sources',
    options: 'Loan Source Option',
  );
}

/// Wraps the widget in MaterialApp > Scaffold > SingleChildScrollView > FormBuilder.
Widget _harness({
  required Widget child,
  GlobalKey<FormBuilderState>? formKey,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: FormBuilder(
          key: formKey ?? GlobalKey<FormBuilderState>(),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('TableMultiSelectField', () {
    testWidgets('renders checkbox group with resolved options', (tester) async {
      final service = FakeLinkOptionService(_standardOptions());

      await tester.pumpWidget(
        _harness(
          child: TableMultiSelectField(
            field: _parentField(),
            getMeta: (doctype) async => _childMeta(),
            linkOptionService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All three options should appear as checkbox labels.
      expect(find.text('SHG'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('PG'), findsOneWidget);

      // Should render checkboxes (one per option).
      expect(find.byType(Checkbox), findsNWidgets(3));
    });

    testWidgets('emits child table row format on selection', (tester) async {
      final service = FakeLinkOptionService(_standardOptions());
      dynamic emittedValue;

      await tester.pumpWidget(
        _harness(
          child: TableMultiSelectField(
            field: _parentField(),
            getMeta: (doctype) async => _childMeta(),
            linkOptionService: service,
            onChanged: (val) => emittedValue = val,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the "SHG" checkbox.
      await tester.tap(find.text('SHG'));
      await tester.pumpAndSettle();

      expect(emittedValue, isA<List>());
      final list = emittedValue as List;
      expect(list.length, 1);
      expect(list[0], {'loan_source': 'SHG'});
    });

    testWidgets('reads initial value in child table row format', (tester) async {
      final service = FakeLinkOptionService(_standardOptions());

      await tester.pumpWidget(
        _harness(
          child: TableMultiSelectField(
            field: _parentField(),
            value: [
              {'loan_source': 'SHG'},
              {'loan_source': 'Bank'},
            ],
            getMeta: (doctype) async => _childMeta(),
            linkOptionService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find all Checkbox widgets and check their state.
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsNWidgets(3));

      // Extract checkbox values — order matches _standardOptions: SHG, Bank, PG.
      final checkboxes = tester.widgetList<Checkbox>(checkboxFinder).toList();
      expect(checkboxes[0].value, isTrue, reason: 'SHG should be checked');
      expect(checkboxes[1].value, isTrue, reason: 'Bank should be checked');
      expect(checkboxes[2].value, isFalse, reason: 'PG should NOT be checked');
    });

    testWidgets('shows loading indicator while resolving', (tester) async {
      final metaCompleter = Completer<DocTypeMeta>();
      final service = FakeLinkOptionService(_standardOptions());

      await tester.pumpWidget(
        _harness(
          child: TableMultiSelectField(
            field: _parentField(),
            getMeta: (doctype) => metaCompleter.future,
            linkOptionService: service,
          ),
        ),
      );

      // After initial pump (not pumpAndSettle), should show loading spinner.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      // Now complete the future and let the widget settle.
      metaCompleter.complete(_childMeta());
      await tester.pumpAndSettle();

      // Loading gone, checkboxes rendered.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(3));
    });
  });
}
