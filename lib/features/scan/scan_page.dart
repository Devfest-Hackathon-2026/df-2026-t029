import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/gemini_service.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  String _result = '';
  bool _loading = false;

  Future<void> _test() async {
    setState(() => _loading = true);
    try {
      final text = await ref
          .read(geminiServiceProvider)
          .generateText('推し活アプリ「おしあし」への応援メッセージを一言ください');
      if (!mounted) return;
      setState(() => _result = text);
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              onPressed: _loading ? null : _test,
              child: const Text('Gemini に接続テスト'),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator() else Text(_result),
          ],
        ),
      ),
    );
  }
}