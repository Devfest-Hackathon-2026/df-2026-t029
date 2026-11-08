import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../../models/oshi.dart';
import '../../utils/oshi_search.dart';
import '../../providers/oshi_providers.dart';
import 'follow_actions.dart';
import 'oshi_list_tile.dart';
import 'group_members_panel.dart';

/// 推しを探す画面（/oshi/search?q=...）
///
/// まずジャンルを選び、そのジャンルの中を名前で探す（Fd 5.6）。
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

  /// ジャンルを選んだか。名前付きで開いたとき（?q=）は「すべて」を選んだ状態にする（Fd 5.6）
  late bool _picked = widget.initialQuery.trim().isNotEmpty;

  /// 選んだジャンル。null なら「すべて」
  OshiGenre? _genre;

  /// フォロー・解除の処理中の推し（OshiSummary.key。== は全項目比較なので使わない）
  final Set<String> _busy = {};

  /// 開く・閉じるを押したグループ（キー → 開いているか）。
  /// 押していないグループは開いておく（Fd 5.5）。検索語・ジャンルを変えたら戻す
  final Map<String, bool> _expanded = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pickGenre(OshiGenre? genre) {
    setState(() {
      _picked = true;
      _genre = genre;
      _expanded.clear();
    });
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

    return HakoPageScaffold(
      title: '推しを探す',
      showBack: true,
      backFallback: '/oshi',
      body: SafeArea(
        child: allAsync.when(
          loading: () => const Center(
            key: Key('oshi_search_loading'),
            child: CircularProgressIndicator(),
          ),
          error: (_, _) =>
              _ErrorView(onRetry: () => ref.invalidate(allOshisProvider)),
          data: (all) => _picked
              ? _searchView(all)
              : _GenrePicker(
                  all: all,
                  onPick: _pickGenre,
                  onRequest: _openRequest,
                ),
        ),
      ),
    );
  }

  /// ジャンルを選んだ後：ジャンルのチップ → 検索欄 → 結果（Fd 5.6）
  Widget _searchView(List<OshiSummary> all) {
    final followAsync = ref.watch(followStateProvider);
    final following = followAsync.value ?? FollowState.empty;
    final hasQuery = _query.trim().isNotEmpty;
    final genre = _genre;
    final pool = genre == null
        ? all
        : all.where((o) => o.genre == genre).toList();
    final results = searchOshis(pool, _query);
    final names = groupNamesById(all);
    final pad = HakoPageScaffold.padding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GenreChip(
                    key: const Key('oshi_genre_chip_all'),
                    label: 'すべて',
                    selected: genre == null,
                    onTap: () => _pickGenre(null),
                  ),
                  for (final g in OshiGenre.values)
                    _GenreChip(
                      key: Key('oshi_genre_chip_${g.code}'),
                      label: g.label,
                      selected: genre == g,
                      onTap: () => _pickGenre(g),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('oshi_search_field'),
                controller: _controller,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: genre == null
                      ? '名前・別名で探す'
                      : '${genre.label}の中から名前・別名で探す',
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() {
                  _query = value;
                  _expanded.clear();
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _EmptyView(
                  query: _query.trim(),
                  genreLabel: genre?.label,
                  onRequest: _openRequest,
                )
              : _resultsView(
                  results,
                  all,
                  following: following,
                  followLoaded: followAsync.hasValue,
                  names: names,
                  hasQuery: hasQuery,
                  pad: pad,
                ),
        ),
      ],
    );
  }

  Widget _resultsView(
    List<OshiSummary> results,
    List<OshiSummary> all, {
    required FollowState following,
    required bool followLoaded,
    required Map<String, String> names,
    required bool hasQuery,
    required EdgeInsets pad,
  }) {
    // 所属グループのある個人は、グループの下に入れる（Fc 4.3）
    final entries = nestOshiResults(results, all);
    return ListView.separated(
      key: const Key('oshi_search_results'),
      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom),
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
              followLoaded: followLoaded,
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
                  followLoaded: followLoaded,
                  names: names,
                  onTap: () => setState(() => _expanded[group.key] = !expanded),
                  membersExpanded: expanded,
                ),
                if (expanded)
                  GroupMembersPanel(
                    group: group,
                    highlightKeys: hasQuery ? hitMemberKeys : const {},
                  ),
              ],
            );
        }
      },
    );
  }
}

/// 最初に出す、ジャンルを選ぶボタンの一覧（Fd 5.6）。
/// 「すべて」と各ジャンル。それぞれに公開されている推しの数を付ける
class _GenrePicker extends StatelessWidget {
  const _GenrePicker({
    required this.all,
    required this.onPick,
    required this.onRequest,
  });

  final List<OshiSummary> all;
  final ValueChanged<OshiGenre?> onPick;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final approved = all.where((o) => o.isApproved).toList();
    int countOf(OshiGenre g) => approved.where((o) => o.genre == g).length;
    final pad = HakoPageScaffold.padding(context);

    return ListView(
      key: const Key('oshi_genre_picker'),
      padding: pad,
      children: [
        Text(
          'まずジャンルを選んでください',
          style: HakoFonts.jp(size: 15, weight: FontWeight.w700, height: 1.5),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 3 : 2;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _GenreButton(
                  key: const Key('oshi_genre_pick_all'),
                  width: width,
                  label: 'すべて',
                  count: approved.length,
                  onTap: () => onPick(null),
                ),
                for (final g in OshiGenre.values)
                  _GenreButton(
                    key: Key('oshi_genre_pick_${g.code}'),
                    width: width,
                    label: g.label,
                    count: countOf(g),
                    onTap: () => onPick(g),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        _RequestFooter(onRequest: onRequest),
      ],
    );
  }
}

/// ジャンルを選ぶボタン1つ（白の地・墨 2px の枠・角丸 12）
class _GenreButton extends StatelessWidget {
  const _GenreButton({
    super.key,
    required this.width,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final double width;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 76,
      child: Material(
        color: BrandColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BrandColors.ink, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HakoFonts.jp(
                    size: 16,
                    weight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                Text(
                  '$count件',
                  style: HakoFonts.jp(
                    size: 12,
                    color: BrandColors.sub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 選んだ後のジャンルのチップ（Fc 3.1 の絞り込みのチップと同じ見た目）。
/// 選んでいるものは墨の地に紙の文字、選んでいないものは白の地に墨の文字
class _GenreChip extends StatelessWidget {
  const _GenreChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? BrandColors.ink : BrandColors.surface,
        shape: const StadiumBorder(
          side: BorderSide(color: BrandColors.ink, width: 2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: HakoFonts.jp(
                size: 13,
                weight: FontWeight.w700,
                height: 1.3,
                color: selected ? BrandColors.paper : BrandColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.query,
    required this.genreLabel,
    required this.onRequest,
  });

  final String query;

  /// 選んだジャンルの名前（「すべて」なら null）
  final String? genreLabel;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final message = switch ((query.isEmpty, genreLabel)) {
      (true, null) => 'まだ公開されている推しがいません',
      (true, final g?) => '$gの推しはまだいません',
      (false, null) => '「$query」に合う推しは見つかりませんでした',
      (false, final g?) => '$gの中に「$query」に合う推しは見つかりませんでした',
    };
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