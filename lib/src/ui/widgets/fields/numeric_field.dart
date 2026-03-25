import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'base_field.dart';

/// Widget for numeric field types (Int, Float, Currency, Percent)
class NumericField extends BaseField {
  final String? Function(dynamic)? validator;

  const NumericField({
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
    final isInt = field.fieldtype == 'Int';
    final isCurrency = field.fieldtype == 'Currency';
    final isPercent = field.fieldtype == 'Percent';

    return FormBuilderTextField(
      key: ValueKey('numeric_${field.fieldname}'),
      name: field.fieldname ?? '',
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: value?.toString() ?? field.defaultValue ?? '',
      enabled: enabled && !field.readOnly,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
      decoration:
          style?.decoration ??
          InputDecoration(
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
            filled: field.readOnly,
            fillColor: field.readOnly ? Colors.grey[200] : null,
            prefixText: isCurrency ? '₹ ' : null,
            suffixText: isPercent ? '%' : null,
          ),
      validator: (value) {
        // Format check: must be a valid number if provided
        if (value != null && value.toString().isNotEmpty) {
          final numValue = isInt
              ? int.tryParse(value.toString())
              : double.tryParse(value.toString());
          if (numValue == null) {
            return 'Please enter a valid number';
          }
        }
        // Merged validator: reqd + external
        return validator?.call(value);
      },
      onChanged: (val) {
        if (val != null && val.isNotEmpty) {
          final numValue = isInt ? int.tryParse(val) : double.tryParse(val);
          onChanged?.call(numValue);
        } else {
          onChanged?.call(null);
        }
      },
    );
  }
}
