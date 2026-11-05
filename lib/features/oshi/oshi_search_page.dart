import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../utils/oshi_search.dart';
import '../../providers/oshi_providers.dart';
import 'follow_actions.dart';
import 'oshi_list_tile.dart';

/// 推しを探す画面（/oshi/search?q=...）
///
/// 購読している全件を端末で絞り込む。検索語が変わっても Firestore は読み直さない。
class OshiSearchPage extends ConsumerStatefulWidget {
  const OshiSearchPage({super.key, this.initialQuery = ''});

  /// 検索欄の初期値
  final String initialQuery;

  @override
  ConsumerState<OshiSearchPage> createState() => _OshiSearchPageState();
}

class _OshiSearchPageState extends ConsumerState<OshiSearchPage> {
  // 初期値は作成時に1回だけ入れる。入力中は text を書き換えない
  // （Web の日本語変換が壊れるため）
  late final _controller = TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;

  /// フォロー・解除の処理中の推し（OshiSummary.key。== は全項目比較なので使わない）
  final Set<String> _busy = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openRequest() {
    final name = _query.trim();
    final location = Uri(
      path: '/oshi/request',
      queryParameters: name.isEmpty ? null : {'name': name},
    ).toString();
    context.push(location);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFollow(OshiSummary oshi, {required bool follow}) async {
    if (_busy.contains(oshi.key)) return;
    setState(() => _busy.add(oshi.key));
    final error = await runFollowAction(ref, oshi, follow: follow);
    // State.context を使うので、State の mounted で確認する
    if (!mounted) return;
    setState(() => _busy.remove(oshi.key));
    if (error != null) _showSnackBar(error);
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allOshisProvider);
    final followAsync = ref.watch(followStateProvider);
    final following = followAsync.value ?? FollowState.empty;

    return Scaffold(
      appBar: AppBar(title: const Text('推しを探す')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('oshi_search_field'),
                controller: _controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '名前・別名で探す',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: allAsync.when(
                loading: () => const Center(
                  key: Key('oshi_search_loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) =>
                    _ErrorView(onRetry: () => ref.invalidate(allOshisProvider)),
                data: (all) {
                  final results = searchOshis(all, _query);
                  if (results.isEmpty) {
                    return _EmptyView(
                      query: _query.trim(),
                      onRequest: _openRequest,
                    );
                  }
                  return ListView.separated(
                    key: const Key('oshi_search_results'),
                    itemCount: results.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i == results.length) {
                        return _RequestFooter(onRequest: _openRequest);
                      }
                      final oshi = results[i];
                      return OshiListTile(
                        oshi: oshi,
                        isFollowing: following.isFollowing(oshi),
                        // フォロー状態を読み込むまでは押せなくする
                        isBusy:
                            !followAsync.hasValue || _busy.contains(oshi.key),
                        onFollow: () => _toggleFollow(oshi, follow: true),
                        onUnfollow: () => _toggleFollow(oshi, follow: false),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.query, required this.onRequest});

  final String query;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final message = query.isEmpty
        ? 'まだ公開されている推しがいません'
        : '「$query」に合う推しは見つかりませんでした';
    return Center(
      key: const Key('oshi_search_empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('見つからない推しは、追加を申請できます', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('oshi_search_request_button'),
              onPressed: onRequest,
              icon: const Icon(Icons.add),
              label: const Text('追加を申請する'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 結果があるときも、リストの最後から申請できるようにする
class _RequestFooter extends StatelessWidget {
  const _RequestFooter({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          key: const Key('oshi_search_footer_request_button'),
          onPressed: onRequest,
          icon: const Icon(Icons.add),
          label: const Text('探している推しがいないときは、追加を申請する'),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('oshi_search_error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('推しの一覧を読み込めませんでした', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('oshi_search_retry_button'),
              onPressed: onRetry,
              child: const Text('もう一度読み込む'),
            ),
          ],
        ),
      ),
    );
  }
}
