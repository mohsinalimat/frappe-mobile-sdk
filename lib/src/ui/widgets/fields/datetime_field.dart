// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'base_field.dart';

/// Widget for Datetime field type
class DatetimeField extends BaseField {
  final String? Function(dynamic)? validator;

  const DatetimeField({
    super.key,
    required super.field,
    super.value,
    super.onChanged,
    super.enabled,
    super.style,
    this.validator,
  });

  @override
  Widget buildField(BuildContext context) {
    DateTime? initialDateTime;
    if (value != null) {
      if (value is DateTime) {
        initialDateTime = value;
      } else if (value is String) {
        initialDateTime = DateTime.tryParse(value);
      }
    }

    return FormBuilderDateTimePicker(
      key: ValueKey('datetime_${field.fieldname}'),
      name: field.fieldname ?? '',
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: initialDateTime,
      enabled: enabled && !field.readOnly,
      inputType: InputType.both,
      format: DateFormat('yyyy-MM-dd HH:mm:ss'),
      decoration:
          style?.decoration ??
          InputDecoration(
            hintText: field.placeholder ?? 'Select date and time',
            border: const OutlineInputBorder(),
            filled: field.readOnly,
            fillColor: field.readOnly ? Colors.grey[200] : null,
            suffixIcon: const Icon(Icons.access_time),
          ),
      validator: (value) => validator?.call(value),
      onChanged: (val) => onChanged?.call(val?.toIso8601String()),
    );
  }
}
