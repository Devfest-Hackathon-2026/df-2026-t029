import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/oshi_providers.dart';
import '../../providers/photo_providers.dart';
import '../../providers/public_profile_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../../utils/photo_picker.dart';
import '../common/user_avatar.dart';

/// プロフィールのアイコンを変える（add_I 3.2）。
/// 選ぶとすぐアップロードして公開プロフィールに保存する（ほかの項目の「保存」とは別）
class ProfileIconEditor extends ConsumerStatefulWidget {
  const ProfileIconEditor({super.key, required this.name});

  /// アイコンが無いときに最初の1文字を出す名前
  final String name;

  @override
  ConsumerState<ProfileIconEditor> createState() => _ProfileIconEditorState();
}

class _ProfileIconEditorState extends ConsumerState<ProfileIconEditor> {
  bool _busy = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 選んでアップロードし、前のファイルを消す
  Future<void> _pick(String uid, String? old) async {
    if (_busy) return;
    final picked = await pickIconPhoto();
    if (!mounted) return;
    if (picked.rejected) {
      _showMessage('画像は 2MB 未満の JPEG・PNG・WebP・GIF にしてください');
      return;
    }
    final photo = picked.photo;
    if (photo == null) return;
    setState(() => _busy = true);
    try {
      final photos = ref.read(photoRepositoryProvider);
      final path = await photos.upload(userIconDir(uid), photo);
      await ref.read(publicProfileRepositoryProvider).setIcon(uid, path);
      if (old != null) await photos.deleteAll([old]);
    } catch (_) {
      if (mounted) _showMessage('アイコンを保存できませんでした。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// アイコンを外す（ファイルも消す）
  Future<void> _remove(String uid, String old) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(publicProfileRepositoryProvider).setIcon(uid, null);
      await ref.read(photoRepositoryProvider).deleteAll([old]);
    } catch (_) {
      if (mounted) _showMessage('アイコンを外せませんでした。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();
    final iconPath = ref.watch(publicProfileProvider(uid)).value?.iconPath;
    return Padding(
      key: const Key('profile_icon_editor'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          UserAvatar(uid: uid, name: widget.name, size: 96),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('profile_icon_pick'),
                      onPressed: _busy ? null : () => _pick(uid, iconPath),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(iconPath == null ? 'アイコンを選ぶ' : 'アイコンを変える'),
                    ),
                    if (iconPath != null)
                      TextButton(
                        key: const Key('profile_icon_remove'),
                        onPressed: _busy ? null : () => _remove(uid, iconPath),
                        child: const Text('外す'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'グッズ交換の投稿・返信・チャットで、ほかの人にも表示されます',
                  style: HakoFonts.jp(
                    size: 12,
                    color: BrandColors.sub,
                    height: 1.5,
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}