// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'base_field.dart';

/// Widget for Duration field type (in seconds)
class DurationField extends BaseField {
  final String? Function(dynamic)? validator;

  const DurationField({
    super.key,
    required super.field,
    super.value,
    super.onChanged,
    super.enabled,
    super.style,
    this.validator,
  });

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int? _parseDuration(String? value) {
    if (value == null || value.isEmpty) return null;

    // Try parsing as integer (seconds)
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    // Try parsing HH:MM:SS format
    final parts = value.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = int.tryParse(parts[2]);
      if (hours != null && minutes != null && seconds != null) {
        return hours * 3600 + minutes * 60 + seconds;
      }
    } else if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) {
        return minutes * 60 + seconds;
      }
    }

    return null;
  }

  @override
  Widget buildField(BuildContext context) {
    int? initialSeconds;
    if (value != null) {
      if (value is int) {
        initialSeconds = value;
      } else if (value is String) {
        initialSeconds = _parseDuration(value);
      }
    }

    return FormBuilderTextField(
      key: ValueKey('duration_${field.fieldname}'),
      name: field.fieldname ?? '',
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: initialSeconds != null
          ? _formatDuration(initialSeconds)
          : null,
      enabled: enabled && !field.readOnly,
      keyboardType: TextInputType.number,
      decoration:
          style?.decoration ??
          InputDecoration(
            hintText: field.placeholder ?? 'HH:MM:SS or seconds',
            border: const OutlineInputBorder(),
            filled: field.readOnly,
            fillColor: field.readOnly ? Colors.grey[200] : null,
            helperText: 'Format: HH:MM:SS or seconds',
          ),
      validator: (value) => validator?.call(value),
      onChanged: (val) {
        final seconds = _parseDuration(val);
        onChanged?.call(seconds);
      },
    );
  }
}
