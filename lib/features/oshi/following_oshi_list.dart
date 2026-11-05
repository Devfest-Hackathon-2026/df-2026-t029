import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/oshi.dart';
import '../../providers/oshi_providers.dart';
import 'follow_actions.dart';
import 'oshi_list_tile.dart';

/// ホームに出す、フォロー中の推しの一覧
///
/// スクロールする親（ListView など）の中に置く前提で、自分ではスクロールしない。
class FollowingOshiList extends ConsumerStatefulWidget {
  const FollowingOshiList({super.key});

  @override
  ConsumerState<FollowingOshiList> createState() => _FollowingOshiListState();
}

class _FollowingOshiListState extends ConsumerState<FollowingOshiList> {
  /// 解除の処理中の推し（OshiSummary.key。== は全項目比較なので使わない）
  final Set<String> _busy = {};

  Future<void> _unfollow(OshiSummary oshi) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    final error = await runFollowAction(ref, oshi, follow: false);
    // State.context を使うので、State の mounted で確認する
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _errorView() {
    return Padding(
      key: const Key('home_following_error'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text('フォロー中の推しを読み込めませんでした', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('home_following_retry_button'),
            onPressed: () {
              ref.invalidate(allOshisProvider);
              ref.invalidate(followStateProvider);
            },
            child: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(followingOshisProvider);

    // 再読み込み中（前の値がある読み込み中）は、前の値を出したままにする
    return switch (following) {
      AsyncError() => _errorView(),
      AsyncValue(value: final list?) when list.isEmpty => const Padding(
        key: Key('home_following_empty'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'まだフォローしている推しはいません。\n「推しを探す」からフォローしてみましょう',
          textAlign: TextAlign.center,
        ),
      ),
      AsyncValue(value: final list?) => Column(
        key: const Key('home_following_list'),
        children: [
          for (final oshi in list)
            OshiListTile(
              oshi: oshi,
              isFollowing: true,
              isBusy: _busy.contains(oshi.key),
              onFollow: () {},
              onUnfollow: () => _unfollow(oshi),
            ),
        ],
      ),
      _ => const Padding(
        key: Key('home_following_loading'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
