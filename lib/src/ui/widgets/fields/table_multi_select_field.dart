import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import '../../../models/doc_field.dart';
import '../../../models/doc_type_meta.dart';
import '../../../services/link_option_service.dart';
import '../../../database/entities/link_option_entity.dart';
import 'base_field.dart';

/// Widget for Table MultiSelect field type.
///
/// Resolves options by:
/// 1. Fetching child DocType meta via [getMeta] (e.g. "Loan Source Option")
/// 2. Finding the first Link field in child meta (e.g. "loan_source" -> "Loan Source")
/// 3. Fetching master DocType records via [linkOptionService] (e.g. SHG, PG, FPO, Bank, Other)
///
/// Emits value as List<Map<String, dynamic>> in Frappe child table row format:
///   [{"loan_source": "SHG"}, {"loan_source": "Bank"}]
class TableMultiSelectField extends BaseField {
  final Future<DocTypeMeta> Function(String doctype) getMeta;
  final LinkOptionService linkOptionService;
  final String? Function(dynamic)? validator;

  const TableMultiSelectField({
    super.key,
    required super.field,
    super.value,
    super.onChanged,
    super.enabled,
    super.style,
    required this.getMeta,
    required this.linkOptionService,
    this.validator,
  });

  @override
  Widget buildField(BuildContext context) {
    return _TableMultiSelectBody(
      field: field,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      style: style,
      getMeta: getMeta,
      linkOptionService: linkOptionService,
      validator: validator,
    );
  }
}

class _TableMultiSelectBody extends StatefulWidget {
  final DocField field;
  final dynamic value;
  final ValueChanged<dynamic>? onChanged;
  final bool enabled;
  final FieldStyle? style;
  final Future<DocTypeMeta> Function(String doctype) getMeta;
  final LinkOptionService linkOptionService;
  final String? Function(dynamic)? validator;

  const _TableMultiSelectBody({
    required this.field,
    this.value,
    this.onChanged,
    required this.enabled,
    this.style,
    required this.getMeta,
    required this.linkOptionService,
    this.validator,
  });

  @override
  State<_TableMultiSelectBody> createState() => _TableMultiSelectBodyState();
}

class _TableMultiSelectBodyState extends State<_TableMultiSelectBody> {
  List<LinkOptionEntity> _options = [];
  String? _linkFieldName;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveOptions();
  }

  Future<void> _resolveOptions() async {
    final childDoctypeName = widget.field.options;
    if (childDoctypeName == null || childDoctypeName.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No child DocType specified';
      });
      return;
    }

    try {
      final childMeta = await widget.getMeta(childDoctypeName);

      DocField? linkField;
      for (final f in childMeta.fields) {
        if (f.fieldtype == 'Link' && f.options != null && f.options!.isNotEmpty) {
          linkField = f;
          break;
        }
      }

      if (linkField == null || linkField.fieldname == null) {
        setState(() {
          _isLoading = false;
          _error = 'No Link field found in $childDoctypeName';
        });
        return;
      }

      _linkFieldName = linkField.fieldname!;
      final masterDoctype = linkField.options!;

      final options = await widget.linkOptionService.getLinkOptions(masterDoctype);

      if (mounted) {
        setState(() {
          _options = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load options: $e';
        });
      }
    }
  }

  List<String> _parseInitialValue() {
    if (widget.value == null) return [];
    if (widget.value is! List) return [];
    final list = widget.value as List;
    final selected = <String>[];
    for (final item in list) {
      if (item is Map && _linkFieldName != null) {
        final val = item[_linkFieldName]?.toString();
        if (val != null && val.isNotEmpty) {
          selected.add(val);
        }
      }
    }
    return selected;
  }

  List<Map<String, dynamic>> _toChildTableRows(List<String>? selected) {
    if (selected == null || selected.isEmpty || _linkFieldName == null) return [];
    return selected.map((name) => <String, dynamic>{_linkFieldName!: name}).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: TextStyle(color: Colors.grey[600])),
      );
    }

    if (_options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No options available'),
      );
    }

    final initialSelected = _parseInitialValue();
    final validInitial = initialSelected
        .where((v) => _options.any((opt) => opt.name == v))
        .toList();

    return FormBuilderCheckboxGroup<String>(
      key: ValueKey('${widget.field.fieldname}_tms_${_options.length}'),
      name: widget.field.fieldname ?? '',
      initialValue: validInitial,
      enabled: widget.enabled && !widget.field.readOnly,
      decoration: widget.style?.decoration ??
          InputDecoration(
            border: const OutlineInputBorder(),
            filled: widget.field.readOnly,
            fillColor: widget.field.readOnly ? Colors.grey[200] : null,
          ),
      options: _options
          .map((opt) => FormBuilderFieldOption(
                value: opt.name,
                child: Text(opt.label ?? opt.name),
              ))
          .toList(),
      validator: (value) => widget.validator?.call(value),
      onChanged: (val) {
        widget.onChanged?.call(_toChildTableRows(val));
      },
    );
  }
}
