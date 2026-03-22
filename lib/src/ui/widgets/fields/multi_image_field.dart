// Copyright (c) 2026, Bhushan Barbuddhe and contributors
// For license information, please see license.txt

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'base_field.dart';

/// A [BaseField] that allows selecting and uploading up to [maxImages] photos.
///
/// Value format: JSON-encoded list of uploaded URLs — `'["url1","url2"]'`
/// Stored as a plain string (Frappe field type: Data).
///
/// When [uploadFile] is provided, each picked image is uploaded immediately
/// and its server URL is stored. Without [uploadFile], local file paths are stored.
class MultiImageField extends BaseField {
  final int maxImages;
  final Future<String?> Function(File file)? uploadFile;
  final String? fileUrlBase;
  final Map<String, String>? imageHeaders;

  const MultiImageField({
    super.key,
    required super.field,
    super.value,
    super.onChanged,
    super.enabled,
    super.style,
    this.maxImages = 4,
    this.uploadFile,
    this.fileUrlBase,
    this.imageHeaders,
  });

  static List<String> parseUrls(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(value.toString());
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget buildField(BuildContext context) {
    return _MultiImageBody(
      initialUrls: parseUrls(value),
      maxImages: maxImages,
      uploadFile: uploadFile,
      fileUrlBase: fileUrlBase,
      imageHeaders: imageHeaders,
      enabled: enabled && !field.readOnly,
      onChanged: (urls) => onChanged?.call(jsonEncode(urls)),
    );
  }
}

class _MultiImageBody extends StatefulWidget {
  final List<String> initialUrls;
  final int maxImages;
  final Future<String?> Function(File file)? uploadFile;
  final String? fileUrlBase;
  final Map<String, String>? imageHeaders;
  final bool enabled;
  final void Function(List<String>) onChanged;

  const _MultiImageBody({
    required this.initialUrls,
    required this.maxImages,
    this.uploadFile,
    this.fileUrlBase,
    this.imageHeaders,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_MultiImageBody> createState() => _MultiImageBodyState();
}

class _MultiImageBodyState extends State<_MultiImageBody> {
  late List<String> _urls;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _urls = List.from(widget.initialUrls);
  }

  String _displayUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = widget.fileUrlBase?.trim() ?? '';
    if (base.isEmpty) return path;
    if (path.startsWith('/private/files/') || path.startsWith('/files/')) {
      final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$b/api/method/frappe.handler.download_file?file_url=${Uri.encodeComponent(path)}';
    }
    return '$base$path';
  }

  bool _isNetworkUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  Future<void> _pickImages() async {
    final remaining = widget.maxImages - _urls.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final results = await picker.pickMultiImage(limit: remaining);
    if (results.isEmpty) return;

    setState(() => _uploading = true);
    final newUrls = <String>[];
    for (final xfile in results) {
      final file = File(xfile.path);
      if (widget.uploadFile != null) {
        try {
          final url = await widget.uploadFile!(file);
          if (url != null && url.isNotEmpty) newUrls.add(url);
        } catch (_) {
          // skip failed upload — don't store broken URL
        }
      } else {
        newUrls.add(file.path);
      }
    }
    setState(() {
      _urls.addAll(newUrls);
      _uploading = false;
    });
    widget.onChanged(_urls);
  }

  Future<void> _pickCamera() async {
    if (_urls.length >= widget.maxImages) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera);
    if (result == null) return;

    setState(() => _uploading = true);
    final file = File(result.path);
    String? url;
    if (widget.uploadFile != null) {
      try {
        url = await widget.uploadFile!(file);
      } catch (_) {}
    } else {
      url = file.path;
    }
    setState(() => _uploading = false);
    if (url != null && url.isNotEmpty) {
      setState(() => _urls.add(url!));
      widget.onChanged(_urls);
    }
  }

  void _removeAt(int index) {
    setState(() => _urls.removeAt(index));
    widget.onChanged(_urls);
  }

  Widget _buildThumb(String url, int index) {
    final displayUrl = _displayUrl(url);
    Widget image;
    if (_isNetworkUrl(displayUrl)) {
      image = Image.network(
        displayUrl,
        fit: BoxFit.cover,
        headers: widget.imageHeaders,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 32),
      );
    } else if (!url.startsWith('/files/') &&
        !url.startsWith('/private/files/')) {
      image = Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 32),
      );
    } else {
      image = const Icon(Icons.image, size: 32);
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: image,
          ),
          if (widget.enabled)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => _removeAt(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.enabled && _urls.length < widget.maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_urls.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _urls.length; i++) _buildThumb(_urls[i], i),
            ],
          ),
        if (_uploading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (canAdd)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: Text('Gallery (${_urls.length}/${widget.maxImages})'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
