import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/gemini_service.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
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
    return HakoPageScaffold(
      title: 'ライブを登録',
      showBack: true,
      backFallback: '/lives/add',
      body: ListView(
        padding: HakoPageScaffold.padding(context),
        children: [
          _MethodCard(
            icon: Icons.document_scanner_outlined,
            title: 'スクショから読み取る',
            description: '告知画像やチケットサイトのスクリーンショットから、日程や期限を自動で読み取ります',
            onTap: _loading ? null : _pickAndExtract,
          ),
          const SizedBox(height: 14),
          _MethodCard(
            icon: Icons.edit_note_outlined,
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
                style: HakoFonts.jp(
                  size: 12,
                  weight: FontWeight.w700,
                  color: BrandColors.errorText,
                ),
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
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: HakoHardShadow(
        radius: 14,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: BrandColors.ink, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Icon(icon, size: 36, color: BrandColors.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: HakoFonts.jp(
                            size: 16,
                            weight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: HakoFonts.jp(
                            size: 13,
                            color: BrandColors.sub,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
