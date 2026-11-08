import '../models/live_memory.dart';

// 座席は、この設計のどこにも出てこない（ShareContent は座席を持たない）。
// 画像・文章・URL・クリップボードのどこにも座席が入らないことを、型で守る。

enum ShareTarget { x, instagram }

enum SharePart { photo, info, setlist, memo, tags, mark }

enum ShareLayer { image, caption }

enum ShareDesign { ticket, photoMain }

/// 画像の形。比率・保存する大きさ・セトリと感想の上限（4.7）
class ShareFormat {
  const ShareFormat(
    this.label,
    this.aspectW,
    this.aspectH,
    this.outWidth,
    this.outHeight,
    this.maxSetlist,
    this.maxMemoChars,
  );

  final String label;
  final int aspectW, aspectH, outWidth, outHeight, maxSetlist, maxMemoChars;
}

const Map<ShareTarget, List<ShareFormat>> shareFormats = {
  ShareTarget.x: [
    ShareFormat('横長 16:9', 16, 9, 1600, 900, 3, 36),
    ShareFormat('正方形 1:1', 1, 1, 1080, 1080, 4, 44),
  ],
  ShareTarget.instagram: [
    ShareFormat('フィード 4:5', 4, 5, 1080, 1350, 6, 72),
    ShareFormat('ストーリー 9:16', 9, 16, 1080, 1920, 10, 150),
  ],
};

/// 各部分で押せる層（4.6）。ここに無い組み合わせは押せない
const Map<SharePart, Set<ShareLayer>> _allowedLayers = {
  SharePart.photo: {ShareLayer.image},
  SharePart.info: {ShareLayer.image, ShareLayer.caption},
  SharePart.setlist: {ShareLayer.image, ShareLayer.caption},
  SharePart.memo: {ShareLayer.image, ShareLayer.caption},
  SharePart.tags: {ShareLayer.caption},
  SharePart.mark: {ShareLayer.image},
};

/// 投稿先ごとの設定。copyWith・toggled で更新する（不変）
class ShareConfig {
  const ShareConfig({
    required this.parts,
    this.formatIndex = 0,
    this.design = ShareDesign.ticket,
    this.backgroundIndex = 0,
  });

  /// 4.6 の表の既定
  factory ShareConfig.defaults(ShareTarget t) => ShareConfig(
    parts: {
      SharePart.photo: {ShareLayer.image},
      SharePart.info: {ShareLayer.image, ShareLayer.caption},
      SharePart.setlist: {ShareLayer.image},
      SharePart.memo: {
        t == ShareTarget.instagram ? ShareLayer.image : ShareLayer.caption,
      },
      SharePart.tags: {ShareLayer.caption},
      SharePart.mark: {ShareLayer.image},
    },
  );

  final Map<SharePart, Set<ShareLayer>> parts;
  final int formatIndex;
  final ShareDesign design;

  /// 0:きいろ 1:みどり 2:ピンク 3:赤 4:青 5:オレンジ 6:紫（黒はなし）
  final int backgroundIndex;

  bool isOn(SharePart p, ShareLayer l) => parts[p]?.contains(l) ?? false;

  /// 押せる組み合わせ（photo・mark は image のみ、tags は caption のみ、
  /// info・setlist・memo は両方）だけを切り替える。押せない組み合わせは何もしない
  ShareConfig toggled(SharePart p, ShareLayer l) {
    if (!(_allowedLayers[p]?.contains(l) ?? false)) return this;
    final next = {
      for (final e in parts.entries) e.key: {...e.value},
    };
    final set = next.putIfAbsent(p, () => <ShareLayer>{});
    if (!set.remove(l)) set.add(l);
    return ShareConfig(
      parts: next,
      formatIndex: formatIndex,
      design: design,
      backgroundIndex: backgroundIndex,
    );
  }

  ShareConfig copyWith({
    int? formatIndex,
    ShareDesign? design,
    int? backgroundIndex,
  }) => ShareConfig(
    parts: parts,
    formatIndex: formatIndex ?? this.formatIndex,
    design: design ?? this.design,
    backgroundIndex: backgroundIndex ?? this.backgroundIndex,
  );
}

/// 投稿・画像に出す内容。**座席は無い**
class ShareContent {
  const ShareContent({
    required this.title,
    required this.startAt,
    required this.venue,
    this.artist,
    this.setlist = const [],
    this.impression,
    this.performerNames = const [],
    this.photoCount = 0,
  });

  /// 記録から作る。座席は読まない。感想は前後の空白を除き、空なら null
  factory ShareContent.fromMemory(
    LiveMemory m, {
    String? artist,
    List<String> performerNames = const [],
  }) {
    final impression = m.impression?.trim();
    return ShareContent(
      title: m.liveTitle,
      startAt: m.startAt,
      venue: m.venue,
      artist: artist,
      setlist: m.setlist,
      impression: (impression == null || impression.isEmpty)
          ? null
          : impression,
      performerNames: performerNames,
      photoCount: m.images.length,
    );
  }

  final String title;
  final DateTime startAt;
  final String venue;
  final String? artist;
  final List<String> setlist;
  final String? impression;
  final List<String> performerNames;
  final int photoCount;
}

/// 先頭の番号の飾り（'1. ' '2) ' '３、' '4: ' など）。区切りの記号が要る
final _numberPrefix = RegExp(r'^[0-9０-９]+\s*[.．)）、，,:：]\s*');

/// 番号と区切りだけの行（'1.' '２）' や数字だけ）
final _numberOnly = RegExp(r'^[0-9０-９]+\s*[.．)）、，,:：]?$');

/// セトリの入力（1行1曲）から先頭の番号を除いた曲名の一覧。空行・番号だけの行は捨てる
List<String> parseSetItems(String text) {
  final out = <String>[];
  for (final raw in text.split(RegExp(r'\r\n|\r|\n'))) {
    final line = raw.trim();
    if (line.isEmpty || _numberOnly.hasMatch(line)) continue;
    final song = line.replaceFirst(_numberPrefix, '').trim();
    if (song.isNotEmpty) out.add(song);
  }
  return out;
}

/// 改行・連続する空白を1つの空白にし、前後を除く
String oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// 日本時間（UTC+9）の値にする。返す DateTime の各項目（年月日・曜日）を読む
DateTime _jst(DateTime t) => t.toUtc().add(const Duration(hours: 9));

String _two(int n) => n.toString().padLeft(2, '0');

const _weekEn = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _weekJa = ['月', '火', '水', '木', '金', '土', '日'];

/// '12.19 SAT'（日本時間。曜日は英語の大文字3文字）
String formatShareDate(DateTime startAt) {
  final d = _jst(startAt);
  return '${_two(d.month)}.${_two(d.day)} ${_weekEn[d.weekday - 1]}';
}

/// '2026/12/19(土)'（日本時間）
String formatCaptionDate(DateTime startAt) {
  final d = _jst(startAt);
  return '${d.year}/${_two(d.month)}/${_two(d.day)}(${_weekJa[d.weekday - 1]})';
}

/// 出演者名（空白を除く・先頭2つまで）に '#' を付け、最後に '#おしあし'
List<String> hashtagsOf(List<String> performerNames) {
  final tags = <String>[];
  for (final name in performerNames) {
    final t = name.replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) continue;
    tags.add('#$t');
    if (tags.length == 2) break;
  }
  return [...tags, '#おしあし'];
}

/// 4.8 の形の文章。**座席は入れない**。cfg の caption に入れた部分だけ
String buildCaption(ShareTarget target, ShareConfig cfg, ShareContent c) {
  final blocks = <String>[];

  final head = <String>['【参戦記録】${c.title}'];
  if (cfg.isOn(SharePart.info, ShareLayer.caption)) {
    head.add('${formatCaptionDate(c.startAt)} @ ${c.venue}');
  }
  if (cfg.isOn(SharePart.setlist, ShareLayer.caption) && c.setlist.isNotEmpty) {
    head.add('セトリ：${c.setlist.join(' / ')}');
  }
  blocks.add(head.join('\n'));

  final impression = c.impression;
  if (cfg.isOn(SharePart.memo, ShareLayer.caption) &&
      impression != null &&
      oneLine(impression).isNotEmpty) {
    blocks.add(oneLine(impression));
  }

  if (cfg.isOn(SharePart.tags, ShareLayer.caption)) {
    blocks.add(hashtagsOf(c.performerNames).join(' '));
  }
  return blocks.join('\n\n');
}

/// X の重み付きの長さ。コードポイントが 0〜4351・8192〜8205・8208〜8223・8242〜8247 は1、
/// それ以外は2（5.12。範囲は X の公式の説明で確かめる）
int xWeightedLength(String text) {
  var n = 0;
  for (final r in text.runes) {
    final light =
        (r >= 0 && r <= 4351) ||
        (r >= 8192 && r <= 8205) ||
        (r >= 8208 && r <= 8223) ||
        (r >= 8242 && r <= 8247);
    n += light ? 1 : 2;
  }
  return n;
}

/// X は 280（重み付き）、Instagram は 2200（素の文字数）
int captionLimit(ShareTarget t) => t == ShareTarget.x ? 280 : 2200;

bool isCaptionTooLong(ShareTarget t, String caption) {
  final len = t == ShareTarget.x
      ? xWeightedLength(caption)
      : caption.runes.length;
  return len > captionLimit(t);
}

/// 画像に入れる文字（上限で切ったあと）
class ShareImageText {
  const ShareImageText(
    this.setShown,
    this.setMore,
    this.memoShown,
    this.memoCut,
  );

  final List<String> setShown; // 先頭 maxSetlist 曲
  final int setMore; // 切った曲数（0なら無し）
  final String memoShown; // maxMemoChars を超えたら、先頭 maxMemoChars 文字＋'…'
  final bool memoCut;
}

/// 形ごとの上限で、セトリと感想を切る。感想は改行を空白にまとめてから数える
ShareImageText layoutShareText(ShareContent c, ShareFormat f) {
  final shown = c.setlist.take(f.maxSetlist).toList();
  final memo = oneLine(c.impression ?? '');
  final runes = memo.runes.toList();
  final cut = runes.length > f.maxMemoChars;
  final memoShown = cut
      ? '${String.fromCharCodes(runes.take(f.maxMemoChars))}…'
      : memo;
  return ShareImageText(shown, c.setlist.length - shown.length, memoShown, cut);
}
