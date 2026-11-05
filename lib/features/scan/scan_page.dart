import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/gemini_service.dart';
import '../live_form/live_draft.dart';

/// ライブの登録方法を選ぶ画面（スクショから読み取る／手入力する）
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  Uint8List? _image;
  String _error = '';
  bool _loading = false;

  Future<void> _pickAndExtract() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();

    setState(() {
      _image = bytes;
      _error = '';
      _loading = true;
    });
    try {
      final data = await ref
          .read(geminiServiceProvider)
          .extractLiveInfo(bytes, file.mimeType ?? 'image/png');
      if (!mounted) return;
      context.push('/live-form', extra: LiveDraft.fromGemini(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '読み取りに失敗しました：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ライブを登録')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MethodCard(
            icon: Icons.document_scanner,
            title: 'スクショから読み取る',
            description: '告知画像やチケットサイトのスクリーンショットから、日程や期限を自動で読み取ります',
            onTap: _loading ? null : _pickAndExtract,
          ),
          const SizedBox(height: 12),
          _MethodCard(
            icon: Icons.edit_note,
            title: '手入力する',
            description: 'ライブ名・公演・受付を自分で入力します',
            onTap: _loading ? null : () => context.push('/live-form'),
          ),
          if (_image != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Image.memory(_image!),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('読み取り中…'),
                ],
              ),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 40),
        title: Text(title),
        subtitle: Text(description),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}