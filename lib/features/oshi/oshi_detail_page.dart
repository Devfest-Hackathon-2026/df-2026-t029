import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/oshi.dart';
import '../../models/oshi_days.dart';
import '../../models/oshi_news.dart';
import '../../providers/favorite_oshi_providers.dart';
import '../../providers/live_providers.dart';
import '../../providers/oshi_color_providers.dart';
import '../../providers/oshi_days_providers.dart';
import '../../providers/oshi_news_providers.dart';
import '../../providers/oshi_providers.dart';
import '../../theme/brand_colors.dart';
import '../../theme/hako_app_widgets.dart';
import '../../theme/hako_fonts.dart';
import '../common/web_iframe.dart';
import '../live/official_url_link.dart' show officialLinkUri, urlLauncherProvider;
import '../live/oshi_upcoming_lives_section.dart';
import '../shell/app_shell.dart';
import 'follow_actions.dart';
import 'group_members_panel.dart';
import 'oshi_color_sheet.dart';
import 'oshi_list_tile.dart';
import 'oshi_menu.dart';

/// 推しのページの場所（add_P 5.2）
String oshiPagePath(OshiSummary oshi) => '/oshi/${oshi.kind.name}/${oshi.id}';

/// 推しのページに出す動画の数（埋め込み1件＋行4件）
const _maxVideos = 5;

/// 日付（端末の時刻で出す）
String _ymd(DateTime d) {
  final l = d.toLocal();
  return '${l.year}/${l.month}/${l.day}';
}

/// 推しのページ（`/oshi/:kind/:id`。add_P 5.2）。
/// 見出し → 記念日と色 → 公式 → 最新の動画 → お知らせ → 今後のライブ → メンバー
class OshiDetailPage extends ConsumerStatefulWidget {
  const OshiDetailPage({super.key, required this.kind, required this.id});

  /// `group`・`person`
  final String kind;
  final String id;

  @override
  ConsumerState<OshiDetailPage> createState() => _OshiDetailPageState();
}

class _OshiDetailPageState extends ConsumerState<OshiDetailPage> {
  /// 本文の幅がこれ以上なら2列（Fe 3.4 と同じ基準）
  static const double _twoColumnWidth = 900;

  bool _busy = false;

  void _showError(String error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _showError(error);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allOshisProvider);
    final list = all.value;
    final oshi = list
        ?.where(
          (o) =>
              o.kind.name == widget.kind && o.id == widget.id && o.isApproved,
        )
        .firstOrNull;
    final padding = HakoPageScaffold.padding(context);

    Widget body;
    if (list == null) {
      body = all.hasError
          ? const HakoEmpty('推しを読み込めませんでした')
          : const Center(child: CircularProgressIndicator());
    } else if (oshi == null) {
      body = const HakoEmpty('この推しは見つかりませんでした');
    } else {
      final left = <Widget>[
        _Header(oshi: oshi, all: list, busy: _busy, run: _run),
        _DaysAndColor(oshi: oshi),
        _OfficialLinks(oshi: oshi),
      ];
      final right = <Widget>[
        _Videos(oshi: oshi),
        _LiveNews(oshi: oshi),
      ];
      final bottom = <Widget>[
        // 今後のライブ（Fd 3.3 の区画をそのまま使う）
        OshiUpcomingLivesSection(oshi: oshi),
        if (oshi.kind == OshiKind.group) ...[
          const HakoSectionHeader('メンバー'),
          GroupMembersPanel(group: oshi, withActions: true),
        ],
      ];
      body = LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns =
              HakoPageScaffold.isWide(context) &&
              constraints.maxWidth - padding.horizontal >= _twoColumnWidth;
          return ListView(
            key: const Key('oshi_detail_page'),
            padding: padding,
            children: [
              if (twoColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...left, ...bottom],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: right,
                      ),
                    ),
                  ],
                )
              else
                ...[...left, ...right, ...bottom],
            ],
          );
        },
      );
    }

    return HakoPageScaffold(
      title: oshi?.name ?? '推し',
      showBack: true,
      backFallback: '/oshi',
      barColor: BrandColors.paper,
      underlineColor: BrandColors.hall1,
      maxContentWidth: kShellMaxContentWidth,
      body: SafeArea(child: body),
    );
  }
}

/// ① 見出しの箱：札・名前・チップ・フォロー／最推し・⋮
class _Header extends ConsumerWidget {
  const _Header({
    required this.oshi,
    required this.all,
    required this.busy,
    required this.run,
  });

  final OshiSummary oshi;
  final List<OshiSummary> all;
  final bool busy;
  final Future<void> Function(Future<String?> Function() action) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = (ref.watch(followStateProvider).value ??
            FollowState.empty)
        .isFollowing(oshi);
    final isFavorite = ref.watch(favoriteOshiKeyProvider).value == oshi.key;
    final groups = [
      for (final id in oshi.groupIds)
        ?all
            .where((o) => o.kind == OshiKind.group && o.id == id)
            .firstOrNull,
    ];
    final menu = oshiMenuItems(
      context,
      oshi,
      isFollowing: isFollowing,
      onUnfollow: () =>
          run(() => runFollowAction(ref, oshi, follow: false)),
      showPageLink: false,
    );

    return HakoBox(
      key: const Key('oshi_detail_header'),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OshiKindBadge(oshi: oshi, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oshi.name,
                  style: HakoFonts.jp(
                    size: 22,
                    weight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    HakoTagChip(oshi.kind.label),
                    HakoTagChip(oshi.genre.label),
                    if (oshi.agency != null) HakoTagChip(oshi.agency!),
                    // 所属のチップを押すとグループのページ
                    for (final g in groups)
                      InkWell(
                        key: Key('oshi_detail_group_${g.id}'),
                        onTap: () => context.push(oshiPagePath(g)),
                        child: HakoTagChip('所属：${g.name} ›', link: true),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (!isFollowing)
                      FilledButton.icon(
                        key: const Key('oshi_detail_follow'),
                        onPressed: busy
                            ? null
                            : () => run(
                                () => runFollowAction(ref, oshi, follow: true),
                              ),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('フォローする'),
                      )
                    else
                      OutlinedButton.icon(
                        key: const Key('oshi_detail_favorite'),
                        onPressed: busy
                            ? null
                            : () => run(
                                () => runFavoriteAction(
                                  ref,
                                  oshi,
                                  favorite: !isFavorite,
                                ),
                              ),
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                        label: Text(isFavorite ? '最推し' : '最推しにする'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (menu.isNotEmpty)
            PopupMenuButton<int>(
              key: const Key('oshi_detail_menu'),
              tooltip: 'メニュー',
              icon: const Icon(Icons.more_vert),
              onSelected: (i) => menu[i].onSelected(),
              itemBuilder: (context) => [
                for (final (i, item) in menu.indexed)
                  PopupMenuItem(
                    value: i,
                    child: Row(
                      children: [
                        Icon(item.icon, size: 20),
                        const SizedBox(width: 12),
                        Text(item.label),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// ② 記念日と色（どれも個人の設定。add_O）
class _DaysAndColor extends ConsumerWidget {
  const _DaysAndColor({required this.oshi});

  final OshiSummary oshi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(oshiDaysProvider).value ?? OshiDays.empty;
    final start = oshiStartDateOf(oshi, days);
    final birthday = oshiBirthdayOf(oshi, days);
    final color = resolveOshiColor(
      oshi,
      ref.watch(oshiColorsProvider).value ?? const {},
    );
    final count = start == null
        ? null
        : oshiDayCount(start, ref.watch(nowProvider));
    final hasAny = start != null || birthday != null || color != null;
    final text = HakoFonts.jp(size: 15, height: 1.6);

    return Column(
      key: const Key('oshi_detail_days'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HakoSectionHeader(
          '記念日・色',
          trailingLabel: hasAny ? '編集' : null,
          onTrailing: hasAny ? () => showOshiColorSheet(context, oshi) : null,
        ),
        if (!hasAny)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('oshi_detail_days_set'),
              onPressed: () => showOshiColorSheet(context, oshi),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('色・絵文字・記念日を設定する'),
            ),
          )
        else
          HakoBox(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (start != null && count != null)
                  Text('推して$count日（${_ymd(start)} から）', style: text),
                if (birthday != null)
                  Text(
                    '${oshi.kind == OshiKind.group ? '結成日' : '誕生日'}　'
                    '${birthday.month}月${birthday.day}日',
                    style: text,
                  ),
                if (color != null)
                  Row(
                    children: [
                      Text('推しの色　', style: text),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: BrandColors.ink),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// ③ 公式のリンク（サイト・X・YouTube）。1つも無ければ何も出さない
class _OfficialLinks extends ConsumerWidget {
  const _OfficialLinks({required this.oshi});

  final OshiSummary oshi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.read(urlLauncherProvider);
    final site = officialLinkUri(oshi.officialUrl);
    final x = oshi.officialX;
    final youtube = oshi.youtubeUrl;
    if (site == null && x == null && youtube == null) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const Key('oshi_detail_official'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HakoSectionHeader('公式'),
        if (site != null)
          HakoRow(
            key: const Key('oshi_detail_official_site'),
            icon: Icons.language,
            title: '公式サイト',
            subs: [site.host],
            onTap: () => open(site),
          ),
        if (x != null)
          HakoRow(
            key: const Key('oshi_detail_official_x'),
            icon: Icons.alternate_email,
            title: 'X',
            subs: ['@$x'],
            onTap: () => open(Uri.https('x.com', '/$x')),
          ),
        if (youtube != null)
          HakoRow(
            key: const Key('oshi_detail_official_youtube'),
            icon: Icons.smart_display_outlined,
            title: 'YouTube',
            subs: [oshi.youtubeTitle ?? oshi.officialYoutube ?? ''],
            onTap: () => open(Uri.parse(youtube)),
          ),
      ],
    );
  }
}

/// ④ 最新の動画（いちばん新しいものは埋め込み、残りは行）。動画が無ければ何も出さない
class _Videos extends ConsumerWidget {
  const _Videos({required this.oshi});

  final OshiSummary oshi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = watchNewsOf(ref, oshi).value ?? const <OshiNews>[];
    final videos = news
        .where((n) => n.type == OshiNewsType.youtube)
        .take(_maxVideos)
        .toList();
    if (videos.isEmpty) return const SizedBox.shrink();
    final open = ref.read(urlLauncherProvider);
    final channel = oshi.youtubeUrl;
    final first = videos.first;

    return Column(
      key: const Key('oshi_detail_videos'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HakoSectionHeader(
          '最新の動画',
          trailingLabel: channel == null ? null : 'YouTube で見る',
          onTrailing: channel == null ? null : () => open(Uri.parse(channel)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: WebIframe(src: first.embedUrl!, title: first.title),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            first.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HakoFonts.jp(size: 14, weight: FontWeight.w700, height: 1.5),
          ),
        ),
        for (final v in videos.skip(1))
          VideoNewsRow(
            news: v,
            // 所属グループの動画には、グループの名前を添える
            showOshiName: v.oshiKey != oshiColorKey(oshi.kind, oshi.id),
          ),
      ],
    );
  }
}

/// 動画の1行（サムネイル・タイトル・日付）。押すと YouTube を開く。ホームでも使う
class VideoNewsRow extends ConsumerWidget {
  const VideoNewsRow({super.key, required this.news, this.showOshiName = false});

  final OshiNews news;

  /// 推しの名前も出すか（所属グループの動画など）
  final bool showOshiName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.read(urlLauncherProvider);
    return InkWell(
      key: Key('video_news_${news.id}'),
      onTap: () => open(Uri.parse(news.videoUrl!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 120,
                height: 68,
                child: Image.network(
                  news.thumbnailUrl!,
                  fit: BoxFit.cover,
                  // 外部の画像の CORS を避ける（add_P 5.5）
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (context, error, stack) =>
                      const ColoredBox(color: BrandColors.paper),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HakoFonts.jp(size: 14, height: 1.5),
                  ),
                  Text(
                    [
                      if (showOshiName && news.oshiName.isNotEmpty) news.oshiName,
                      _ymd(news.publishedAt),
                    ].join('・'),
                    style: HakoFonts.jp(
                      size: 12,
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
    );
  }
}

/// ⑤ お知らせ（公式サイトから見つかった新しいライブ。14日以内）。無ければ何も出さない
class _LiveNews extends ConsumerWidget {
  const _LiveNews({required this.oshi});

  final OshiSummary oshi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = watchNewsOf(ref, oshi).value ?? const <OshiNews>[];
    final lives = recentNews(
      news.where((n) => n.type == OshiNewsType.live).toList(),
      ref.watch(nowProvider),
    );
    if (lives.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('oshi_detail_news'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HakoSectionHeader('お知らせ'),
        for (final n in lives)
          HakoRow(
            key: Key('oshi_detail_news_${n.id}'),
            icon: Icons.confirmation_number_outlined,
            title: n.title,
            subs: [
              '${n.oshiName}・公式サイトから登録（${_ymd(n.publishedAt)}）',
            ],
            onTap: () => context.push('/lives/${n.liveId}'),
          ),
      ],
    );
  }
}