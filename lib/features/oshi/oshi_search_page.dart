import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/hako_app_widgets.dart';
import '../../models/oshi.dart';
import '../../utils/oshi_search.dart';
import '../../providers/oshi_providers.dart';
import 'follow_actions.dart';
import 'oshi_list_tile.dart';
import 'group_members_panel.dart';

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

  /// 開く・閉じるを押したグループ（キー → 開いているか）。
  /// 押していないグループは、検索でヒットしたメンバーがいれば開いておく。
  /// 検索語を変えたら戻す（Fc 4.3）
  final Map<String, bool> _expanded = {};

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

  /// 1行の推し（個人の行・グループの行の共通部分）
  Widget _tile(
    OshiSummary oshi, {
    required FollowState following,
    required bool followLoaded,
    required Map<String, String> names,
    VoidCallback? onTap,
    bool? membersExpanded,
  }) {
    return OshiListTile(
      oshi: oshi,
      isFollowing: following.isFollowing(oshi),
      // フォロー状態を読み込むまでは押せなくする
      isBusy: !followLoaded || _busy.contains(oshi.key),
      onFollow: () => _toggleFollow(oshi, follow: true),
      onUnfollow: () => _toggleFollow(oshi, follow: false),
      onTap: onTap,
      membersExpanded: membersExpanded,
      groupNames: groupNamesOf(oshi, names),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allOshisProvider);
    final followAsync = ref.watch(followStateProvider);
    final following = followAsync.value ?? FollowState.empty;
    final hasQuery = _query.trim().isNotEmpty;

    return HakoPageScaffold(
      title: '推しを探す',
      showBack: true,
      backFallback: '/oshi',
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
                onChanged: (value) => setState(() {
                  _query = value;
                  _expanded.clear();
                }),
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
                  final names = groupNamesById(all);
                  // 所属グループのある個人は、グループの下に入れる（Fc 4.3）
                  final entries = nestOshiResults(results, all);
                  return ListView.separated(
                    key: const Key('oshi_search_results'),
                    itemCount: entries.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i == entries.length) {
                        return _RequestFooter(onRequest: _openRequest);
                      }
                      switch (entries[i]) {
                        case PersonSearchEntry(:final person):
                          return _tile(
                            person,
                            following: following,
                            followLoaded: followAsync.hasValue,
                            names: names,
                          );
                        case GroupSearchEntry(:final group, :final hitMemberKeys):
                          // グループは最初から開いておく（Fd 5.5）
                          final expanded = _expanded[group.key] ?? true;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _tile(
                                group,
                                following: following,
                                followLoaded: followAsync.hasValue,
                                names: names,
                                onTap: () => setState(
                                  () => _expanded[group.key] = !expanded,
                                ),
                                membersExpanded: expanded,
                              ),
                              if (expanded)
                                GroupMembersPanel(
                                  group: group,
                                  highlightKeys:
                                      hasQuery ? hitMemberKeys : const {},
                                ),
                            ],
                          );
                      }
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
