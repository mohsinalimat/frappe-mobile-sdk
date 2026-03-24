import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'base_field.dart';

/// Widget for Text, Long Text, and Small Text field types
class TextFieldWidget extends BaseField {
  final String? Function(dynamic)? validator;

  const TextFieldWidget({
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
    final isLongText =
        field.fieldtype == 'Long Text' || field.fieldtype == 'Text';
    final maxLines = isLongText ? 5 : 3;

    return FormBuilderTextField(
      key: ValueKey('text_${field.fieldname}'),
      name: field.fieldname ?? '',
      initialValue: value?.toString() ?? field.defaultValue ?? '',
      enabled: enabled && !field.readOnly,
      decoration:
          style?.decoration ??
          InputDecoration(
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
            filled: field.readOnly,
            fillColor: field.readOnly ? Colors.grey[200] : null,
          ),
      maxLines: maxLines,
      maxLength: (field.length != null && field.length! > 0)
          ? field.length
          : null,
      validator: (value) => validator?.call(value),
      onChanged: (val) => onChanged?.call(val),
    );
  }
}
