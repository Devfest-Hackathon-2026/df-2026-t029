// 紹介ページ（/welcome）。ログインしていない人が最初に見るページ。
//
// 構成:
//   ① 最初の画面: 画面いっぱいの写真＋アプリ名（太字をピンクに光らせる）＋キャッチコピー
//   ② 下にスクロール: 明るい区画に、6つの機能を「番号＋見出し＋説明」で並べる（枠なし。細い線で区切る）
//   ③ いちばん下: 夜の色に戻して、締めのひとことと「始める」ボタン
//
// ログイン:
//   「始める」と右上の「ログイン」は、ログイン画面（/login）を挟まずに、その場で Google のログイン
//   （ポップアップ）を開く。ログインできたら、ルーターがホーム（初回はプロフィールの作成）へ移す。
//   /login のルートとログイン画面は、URL を直接開いた場合のために残している。
//
// 書体:
//   - アプリ名・見出し・本文: 既定の書体（日本語の書体は1つが数MBあり、初回の読み込みが遅くなるため）
//   - 英字・番号: Outfit（google_fonts パッケージ。SIL Open Font License。著作物利用シートに書く）
//
// 写真が決まったら:
//   1. 写真を assets/images/welcome_hero.jpg に置く（横長・暗めの写真だと文字が読みやすい）
//   2. pubspec.yaml の flutter: の下に追加する
//        assets:
//          - assets/images/welcome_hero.jpg
//   3. 下の _heroImage にパスを書く
//   4. 写真の色に合わせて _Palette の色を選び直す
//   5. 著作物利用シートに、写真の出典とライセンスを書く

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../repositories/auth_repository.dart';
import '../live/official_url_link.dart' show urlLauncherProvider;

/// 最初の画面の写真。空のあいだは、仮の背景（照明のようなグラデーション）を出す。
/// 例: 'assets/images/welcome_hero.jpg'
const String _heroImage = '';

/// 紹介ページの文言（あとで直しやすいよう、ここにまとめる）
abstract final class _Copy {
  static const appName = 'おしあし';
  static const appNameSub = 'OSHIASHI';
  static const catchCopy = '推し活の予定を、ひとつに。';
  static const lead = 'ライブの日程も、申込・入金の締切も。\nスクショ1枚から、まとめて管理できます。';
  static const scrollHint = 'SCROLL';
  static const login = 'ログイン';
  static const featuresKicker = 'FEATURES';
  static const featuresTitle = 'おしあしで、できること';
  static const featuresLead = '推し活の「忘れてた！」を、なくすための6つの機能';
  static const closing = '推し活の予定を、\nもう逃さない。';
  static const start = '始める';
  static const startNote =
      '押すと Google のログインの画面が開きます。\n'
      'カレンダーへの追加は、使うときに改めて許可を求めます。';
  static const loginFailed = 'ログインに失敗しました';
  static const photoPlaceholder = 'ここに写真が入ります（いまは仮の背景）';
}

/// 色（夜のライブ会場とペンライトのイメージ。写真が決まったら写真の色から選び直す）
abstract final class _Palette {
  // 暗い区画（最初の画面・締め）
  static const night = Color(0xFF0E0A1F);
  static const violet = Color(0xFF2E1A5C);
  static const text = Colors.white;
  static const subText = Color(0xBFFFFFFF); // 白の 75%
  // 明るい区画（機能）
  static const paper = Color(0xFFFAF8FD); // ほんのり紫がかった白
  static const ink = Color(0xFF1A1033); // 濃い紫紺の文字
  static const inkSub = Color(0xFF5E5A72);
  static const line = Color(0xFFE6E0F0);
  // 差し色（ペンライト）
  static const pink = Color(0xFFFF4FA3);
  static const purple = Color(0xFF8B5CF6);
}

/// 書体
abstract final class _Fonts {
  /// 見出し（既定の書体の太字。読みやすさを優先）
  static TextStyle display({
    required double size,
    Color color = _Palette.text,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: size * 0.04,
    height: 1.45,
    shadows: shadows,
  );

  /// 英字・番号（Outfit）
  static TextStyle latin({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = _Palette.text,
    double letterSpacing = 0,
  }) => GoogleFonts.outfit(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1,
  );

  /// 本文（既定の書体）
  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = _Palette.text,
    double height = 1.8,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

/// 6つの機能（見出し、説明）。番号は並び順から付ける
const _features = <(String, String)>[
  ('推しをフォロー', '応援している推しを探してフォロー。見つからなければ、追加を申請できます。'),
  ('スクショから読み取り', '告知画像やチケットサイトのスクショから、日程・申込期限・入金期限を AI が読み取ります。'),
  ('みんなで共有', '同じ推しのファンが登録したライブを探して、自分の一覧に追加。入力の手間がいりません。'),
  ('次の締切がひと目で', '申込 → 当落 → 入金。申込状況に合わせて、次にやることの期限に切り替わります。'),
  ('Google カレンダーに追加', '公演や申込・入金の期限を、Google カレンダーにまとめて追加できます。'),
  ('グッズ交換', '譲・求を登録すると、交換できる相手が見つかります。手渡しする公演も選べます。'),
];

/// 紹介ページ（ログインしていない人が最初に見るページ）
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToFeatures(double heroHeight) {
    _scroll.animateTo(
      heroHeight,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 最初の画面は画面の高さいっぱい（低すぎる画面では 560 を下限にする）
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = screenHeight < 560 ? 560.0 : screenHeight;

    return Scaffold(
      backgroundColor: _Palette.night,
      body: SingleChildScrollView(
        key: const Key('welcome_page'),
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              height: heroHeight,
              onScrollHint: () => _scrollToFeatures(heroHeight),
            ),
            const _Features(),
            const _Closing(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ① 最初の画面
// ---------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.height, required this.onScrollHint});

  final double height;
  final VoidCallback onScrollHint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _HeroBackground(),
          // 文字を読みやすくするため、写真の下側を暗くする
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000E0A1F), Color(0xD90E0A1F), _Palette.night],
                stops: [0.35, 0.8, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _SignInAction(
                      key: const Key('welcome_login_button'),
                      builder: (context, onPressed) => OutlinedButton(
                        onPressed: onPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Palette.text,
                          disabledForegroundColor: _Palette.subText,
                          backgroundColor: const Color(0x40000000),
                          side: const BorderSide(color: Color(0x66FFFFFF)),
                          shape: const StadiumBorder(),
                          textStyle: _Fonts.body(
                            size: 14,
                            weight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                        child: const Text(_Copy.login),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    child: _HeroText(onScrollHint: onScrollHint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.onScrollHint});

  final VoidCallback onScrollHint;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final nameSize = _clamp(width * 0.11, 48, 96);
    final catchSize = _clamp(width * 0.046, 20, 30);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _Copy.appName,
          textAlign: TextAlign.center,
          // 既定の書体の太字に、ペンライトの光のようなピンクの光彩
          style: TextStyle(
            color: _Palette.text,
            fontSize: nameSize,
            fontWeight: FontWeight.w900,
            letterSpacing: nameSize * 0.06,
            height: 1.15,
            shadows: const [
              Shadow(color: Color(0xD9FF4FA3), blurRadius: 18),
              Shadow(color: Color(0x80FF4FA3), blurRadius: 46),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _Copy.appNameSub,
          style: _Fonts.latin(
            size: 14,
            color: _Palette.subText,
            letterSpacing: 7,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _Copy.catchCopy,
          textAlign: TextAlign.center,
          style: _Fonts.body(
            size: catchSize,
            weight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _Copy.lead,
          textAlign: TextAlign.center,
          style: _Fonts.body(size: 15, color: _Palette.subText),
        ),
        const SizedBox(height: 20),
        TextButton(
          key: const Key('welcome_scroll_hint'),
          onPressed: onScrollHint,
          style: TextButton.styleFrom(foregroundColor: _Palette.subText),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _Copy.scrollHint,
                style: _Fonts.latin(
                  size: 12,
                  weight: FontWeight.w500,
                  color: _Palette.subText,
                  letterSpacing: 3.6,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 26),
            ],
          ),
        ),
      ],
    );
  }
}

/// 写真（未設定・読み込み失敗のときは仮の背景）
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    if (_heroImage.isEmpty) return const _HeroPlaceholder();
    return Image.asset(
      _heroImage,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
    );
  }
}

/// 写真が決まるまでの仮の背景（ライブ会場の照明のようなグラデーション）
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF24124A), Color(0xFF120A2A), _Palette.night],
              stops: [0, 0.6, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.65),
              radius: 0.8,
              colors: [Color(0x8CB67CFF), Color(0x00B67CFF)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5, -0.75),
              radius: 0.7,
              colors: [Color(0x733FD9FF), Color(0x003FD9FF)],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 72),
            child: Text(
              _Copy.photoPlaceholder,
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// ② 6つの機能（明るい区画。上の角を丸め、最初の画面に重なるシートのように見せる）
// ---------------------------------------------------------------------

class _Features extends StatelessWidget {
  const _Features();

  static const _maxWidth = 1040.0;
  static const _columnGap = 48.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: _Palette.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // ペンライトの色を、ほんのり背景ににじませる
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 0.9,
                  colors: [Color(0x1AFF4FA3), Color(0x00FF4FA3)],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  radius: 0.9,
                  colors: [Color(0x1F3FD9FF), Color(0x003FD9FF)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 88, 24, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  children: [
                    Text(
                      _Copy.featuresKicker,
                      style: _Fonts.latin(
                        size: 13,
                        color: _Palette.pink,
                        letterSpacing: 5.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _Copy.featuresTitle,
                      textAlign: TextAlign.center,
                      style: _Fonts.display(
                        size: _clamp(MediaQuery.sizeOf(context).width * 0.054, 26, 42),
                        color: _Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _Copy.featuresLead,
                      textAlign: TextAlign.center,
                      style: _Fonts.body(size: 15, color: _Palette.inkSub),
                    ),
                    const SizedBox(height: 56),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 960 ? 3 : (width >= 640 ? 2 : 1);
                        final itemWidth =
                            (width - _columnGap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: _columnGap,
                          children: [
                            for (final (i, (title, body)) in _features.indexed)
                              SizedBox(
                                width: itemWidth,
                                child: _FeatureItem(
                                  number: (i + 1).toString().padLeft(2, '0'),
                                  title: title,
                                  body: body,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 機能1つ（枠で囲まず、上の細い線で区切る）
class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _Palette.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 28, 0, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 番号をピンク → 紫のグラデーションで塗る
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_Palette.pink, _Palette.purple],
              ).createShader(bounds),
              child: Text(
                number,
                style: _Fonts.latin(
                  size: 44,
                  weight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: _Fonts.body(
                size: 19,
                weight: FontWeight.w700,
                color: _Palette.ink,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: _Fonts.body(size: 14, color: _Palette.inkSub, height: 1.85),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ③ 締めと「始める」（最初の画面と同じ夜の色で挟む）
// ---------------------------------------------------------------------

class _Closing extends StatelessWidget {
  const _Closing();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Palette.night, _Palette.violet],
        ),
      ),
      child: DecoratedBox(
        // 上のほうに、ステージの照明のようなピンクの光
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 0.9,
            colors: [Color(0x40FF4FA3), Color(0x00FF4FA3)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 88, 16, 96),
            child: Column(
              children: [
                Text(
                  _Copy.closing,
                  textAlign: TextAlign.center,
                  style: _Fonts.display(
                    size: _clamp(MediaQuery.sizeOf(context).width * 0.05, 24, 34),
                  ),
                ),
                const SizedBox(height: 32),
                const _StartButton(key: Key('welcome_start_button')),
                const SizedBox(height: 16),
                Text(
                  _Copy.startNote,
                  textAlign: TextAlign.center,
                  style: _Fonts.body(size: 12, color: _Palette.subText),
                ),
                const SizedBox(height: 10),
                const _RecaptchaNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「始める」ボタン（ピンク → 紫のグラデーションで光らせる）。押すと Google のログインを開く
class _StartButton extends StatelessWidget {
  const _StartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return _SignInAction(
      builder: (context, onPressed) => DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          gradient: LinearGradient(colors: [_Palette.pink, _Palette.purple]),
          boxShadow: [BoxShadow(color: Color(0x8CFF4FA3), blurRadius: 28)],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: _Palette.text,
            disabledForegroundColor: _Palette.subText,
            minimumSize: const Size(260, 58),
            shape: const StadiumBorder(),
            textStyle: _Fonts.body(
              size: 18,
              weight: FontWeight.w700,
              height: 1,
            ).copyWith(letterSpacing: 3.6),
          ),
          child: onPressed == null
              // ログインの画面が開いている間は、くるくるを出して押せなくする
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _Palette.text,
                  ),
                )
              : const Text(_Copy.start),
        ),
      ),
    );
  }
}

/// Google でログインする（ポップアップ）。ログインできたら、ルーターが自動で
/// ホーム（初回はプロフィールの作成）へ移すので、ここでは画面を移さない。
/// 処理中は [builder] に null を渡し、ボタンを押せなくする（二重に開かない）。
class _SignInAction extends ConsumerStatefulWidget {
  const _SignInAction({super.key, required this.builder});

  final Widget Function(BuildContext context, VoidCallback? onPressed) builder;

  @override
  ConsumerState<_SignInAction> createState() => _SignInActionState();
}

class _SignInActionState extends ConsumerState<_SignInAction> {
  bool _busy = false;

  /// ユーザーが自分でポップアップを閉じたときのエラー（知らせない）
  static const _cancelCodes = {'popup-closed-by-user', 'cancelled-popup-request'};

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (!_cancelCodes.contains(e.code)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_Copy.loginFailed}（${e.code}）')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _busy ? null : _signIn);
}

/// reCAPTCHA のバッジを隠す代わりに出す、Google の規約で求められる文言
/// （ログイン画面から移した。暗い背景用の色）
class _RecaptchaNotice extends ConsumerStatefulWidget {
  const _RecaptchaNotice();

  @override
  ConsumerState<_RecaptchaNotice> createState() => _RecaptchaNoticeState();
}

class _RecaptchaNoticeState extends ConsumerState<_RecaptchaNotice> {
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open('https://policies.google.com/privacy');
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open('https://policies.google.com/terms');

  Future<void> _open(String url) =>
      ref.read(urlLauncherProvider)(Uri.parse(url));

  @override
  void dispose() {
    _privacy.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _Fonts.body(size: 11, color: const Color(0x8CFFFFFF), height: 1.7);
    final link = base.copyWith(
      color: const Color(0xCCFFFFFF),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xCCFFFFFF),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Text.rich(
        key: const Key('welcome_recaptcha_notice'),
        textAlign: TextAlign.center,
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'このサイトは reCAPTCHA で保護されており、Google の'),
            TextSpan(text: 'プライバシーポリシー', style: link, recognizer: _privacy),
            const TextSpan(text: 'と'),
            TextSpan(text: '利用規約', style: link, recognizer: _terms),
            const TextSpan(text: 'が適用されます。'),
          ],
        ),
      ),
    );
  }
}

/// [value] を [min] 以上 [max] 以下に収める
double _clamp(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);
