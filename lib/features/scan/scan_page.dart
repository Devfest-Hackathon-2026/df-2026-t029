import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../live_form/live_draft.dart';
import '../../services/gemini_service.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  Uint8List? _image;
  String _result = '';
  bool _loading = false;

  Future<void> _pickAndExtract() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();

    setState(() {
      _image = bytes;
      _result = '';
      _loading = true;
    });
    try {
      final data = await ref
          .read(geminiServiceProvider)
          .extractLiveInfo(bytes, file.mimeType ?? 'image/png');
      if (!mounted) return;
      context.push('/live-form', extra: LiveDraft.fromGemini(data));
      // setState(() =>
      //     _result = const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('スクショ読み取り')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _pickAndExtract,
            icon: const Icon(Icons.image),
            label: const Text('画像を選んで読み取る'),
          ),
          if (_image != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Image.memory(_image!),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SelectableText(_result),
        ],
      ),
    );
  }
}