import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/public_profile_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import 'storage_image.dart';

/// ユーザーのアイコン（add_I 3.3）。公開プロフィールにアイコンがあれば丸く切り抜いて出す。
/// 無い・読み込み中・読めないときは、名前の最初の1文字を白地に墨の丸で出す
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.size = 24,
  });

  final String uid;

  /// アイコンが無いときに最初の1文字を出す名前
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = uid.isEmpty
        ? null
        : ref.watch(publicProfileProvider(uid)).value?.iconPath;
    final initial = name.trim().characters.firstOrNull ?? '?';
    return Semantics(
      label: '$nameのアイコン',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: BrandColors.surface,
        ),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: BrandColors.ink,
            width: size >= 48 ? 2 : 1.5,
          ),
        ),
        child: path != null
            ? ClipOval(
                child: SizedBox.expand(child: StorageImage(path: path)),
              )
            : Text(
                initial,
                style: HakoFonts.jp(
                  size: size * 0.45,
                  weight: FontWeight.w700,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
