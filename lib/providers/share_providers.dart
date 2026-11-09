import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/share_ticket.dart';

/// 投稿の画面の状態。保存しない（画面を閉じたら既定に戻る。5.14）
class ShareState {
  const ShareState({
    required this.target,
    required this.configs,
    this.captionOverride = const {},
    this.imageSaved = false,
    this.captionCopied = false,
    this.sharePhotos = const {},
  });

  /// 既定: 投稿先は X・設定は 4.6 の既定
  factory ShareState.initial() => ShareState(
    target: ShareTarget.x,
    configs: {for (final t in ShareTarget.values) t: ShareConfig.defaults(t)},
  );

  final ShareTarget target;
  final Map<ShareTarget, ShareConfig> configs;

  /// 手直し済みの文章（無い・null なら自動で作る）
  final Map<ShareTarget, String?> captionOverride;

  /// Instagram の番号の丸の色（画像を保存した・文章をコピーした）
  final bool imageSaved, captionCopied;

  /// 投稿先ごとの、画像に入れる写真（Storage のパス）。null・無し＝記録と同じ（未操作）
  final Map<ShareTarget, List<String>?> sharePhotos;

  /// 今の投稿先の設定
  ShareConfig get config => configs[target]!;

  ShareState copyWith({
    ShareTarget? target,
    Map<ShareTarget, ShareConfig>? configs,
    Map<ShareTarget, String?>? captionOverride,
    bool? imageSaved,
    bool? captionCopied,
    Map<ShareTarget, List<String>?>? sharePhotos,
  }) => ShareState(
    target: target ?? this.target,
    configs: configs ?? this.configs,
    captionOverride: captionOverride ?? this.captionOverride,
    imageSaved: imageSaved ?? this.imageSaved,
    captionCopied: captionCopied ?? this.captionCopied,
    sharePhotos: sharePhotos ?? this.sharePhotos,
  );
}

/// 投稿の画面の状態の更新。[performanceId] ごとに別の状態を持つ
class ShareNotifier extends Notifier<ShareState> {
  ShareNotifier(this.performanceId);

  final String performanceId;

  @override
  ShareState build() => ShareState.initial();

  /// 投稿先を切り替える。画像の形は 1 つめに戻す
  void selectTarget(ShareTarget t) {
    state = state.copyWith(
      target: t,
      configs: {
        ...state.configs,
        t: state.configs[t]!.copyWith(formatIndex: 0),
      },
    );
  }

  void _setConfig(ShareConfig cfg) {
    state = state.copyWith(configs: {...state.configs, state.target: cfg});
  }

  /// のせる部分を切り替える。手直し済みの文章は残す
  /// （自動に戻すのは [resetCaption] のときだけ）
  void toggle(SharePart p, ShareLayer l) {
    final next = state.config.toggled(p, l);
    if (identical(next, state.config)) return; // 押せない組み合わせ
    _setConfig(next);
  }

  void setFormat(int i) {
    final max = shareFormats[state.target]!.length;
    if (i < 0 || i >= max) return;
    _setConfig(state.config.copyWith(formatIndex: i));
  }

  void setDesign(ShareDesign d) => _setConfig(state.config.copyWith(design: d));

  void setBackground(int i) =>
      _setConfig(state.config.copyWith(backgroundIndex: i));

  /// 文章を手直し済みにする
  void setCaption(String text) {
    state = state.copyWith(
      captionOverride: {...state.captionOverride, state.target: text},
    );
  }

  /// 自動で作った文章に戻す
  void resetCaption() {
    state = state.copyWith(
      captionOverride: {...state.captionOverride, state.target: null},
    );
  }

  /// 今の投稿先の、いまの写真の一覧（未操作なら記録の先頭 kShareMaxPhotos 枚）
  List<String> _currentPhotos(List<String> recordImages) =>
      effectiveSharePhotos(state, recordImages);

  void _setPhotos(List<String>? list) {
    state = state.copyWith(
      sharePhotos: {...state.sharePhotos, state.target: list},
    );
  }

  /// 足す。すでに上限・すでに入っている・recordImages に無いときは何もせず false
  bool addSharePhoto(String path, List<String> recordImages) {
    if (!recordImages.contains(path)) return false;
    final current = _currentPhotos(recordImages);
    if (current.length >= kShareMaxPhotos || current.contains(path)) {
      return false;
    }
    _setPhotos([...current, path]);
    return true;
  }

  /// 外す（未操作なら、先に今の一覧をコピーして操作済みにする）
  void removeSharePhoto(String path, List<String> recordImages) {
    final current = _currentPhotos(recordImages);
    _setPhotos([
      for (final p in current)
        if (p != path) p,
    ]);
  }

  /// 記録と同じに戻す
  void resetSharePhotos() => _setPhotos(null);

  /// 大きさ。ShareSizes の範囲・刻みに収める
  void setSizes(ShareSizes sizes) => _setConfig(
    state.config.copyWith(
      sizes: ShareSizes.normal.copyWith(
        photo: sizes.photo,
        info: sizes.info,
        setlist: sizes.setlist,
      ),
    ),
  );

  void resetSizes() =>
      _setConfig(state.config.copyWith(sizes: ShareSizes.normal));

  void markImageSaved() => state = state.copyWith(imageSaved: true);

  void markCaptionCopied() => state = state.copyWith(captionCopied: true);
}

/// 投稿の画面の状態（[performanceId] ごと）
final shareProvider = NotifierProvider.autoDispose
    .family<ShareNotifier, ShareState, String>(ShareNotifier.new);

/// 今の文章（手直しがあればそれ、なければ自動で作ったもの）
String currentCaption(ShareState s, ShareContent c) =>
    s.captionOverride[s.target] ?? buildCaption(s.target, s.config, c);

/// 今の投稿先の、画像に入れる写真（最大 kShareMaxPhotos）。
/// 未操作なら recordImages の先頭4枚。操作済みなら自分の一覧から、recordImages に無いものを落とす
List<String> effectiveSharePhotos(ShareState s, List<String> recordImages) {
  final own = s.sharePhotos[s.target];
  if (own == null) return recordImages.take(kShareMaxPhotos).toList();
  return [
    for (final p in own)
      if (recordImages.contains(p)) p,
  ].take(kShareMaxPhotos).toList();
}

/// 操作済みか（「記録と同じ写真に戻す」を出すか）
bool isSharePhotosTouched(ShareState s) => s.sharePhotos[s.target] != null;
