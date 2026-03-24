// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'base_field.dart';

/// Widget for Password field type
class PasswordField extends BaseField {
  final String? Function(dynamic)? validator;

  const PasswordField({
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
    return FormBuilderTextField(
      key: ValueKey('password_${field.fieldname}'),
      name: field.fieldname ?? '',
      initialValue: value?.toString() ?? field.defaultValue ?? '',
      enabled: enabled && !field.readOnly,
      obscureText: true,
      decoration:
          style?.decoration ??
          InputDecoration(
            hintText: field.placeholder ?? 'Enter password',
            border: const OutlineInputBorder(),
            filled: field.readOnly,
            fillColor: field.readOnly ? Colors.grey[200] : null,
            suffixIcon: const Icon(Icons.lock),
          ),
      validator: (value) => validator?.call(value),
      onChanged: (val) => onChanged?.call(val),
    );
  }
}
