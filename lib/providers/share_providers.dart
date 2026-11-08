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

  /// 今の投稿先の設定
  ShareConfig get config => configs[target]!;

  ShareState copyWith({
    ShareTarget? target,
    Map<ShareTarget, ShareConfig>? configs,
    Map<ShareTarget, String?>? captionOverride,
    bool? imageSaved,
    bool? captionCopied,
  }) => ShareState(
    target: target ?? this.target,
    configs: configs ?? this.configs,
    captionOverride: captionOverride ?? this.captionOverride,
    imageSaved: imageSaved ?? this.imageSaved,
    captionCopied: captionCopied ?? this.captionCopied,
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

  void markImageSaved() => state = state.copyWith(imageSaved: true);

  void markCaptionCopied() => state = state.copyWith(captionCopied: true);
}

/// 投稿の画面の状態（[performanceId] ごと）
final shareProvider = NotifierProvider.autoDispose
    .family<ShareNotifier, ShareState, String>(ShareNotifier.new);

/// 今の文章（手直しがあればそれ、なければ自動で作ったもの）
String currentCaption(ShareState s, ShareContent c) =>
    s.captionOverride[s.target] ?? buildCaption(s.target, s.config, c);
