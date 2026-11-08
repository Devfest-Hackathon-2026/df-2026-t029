import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'hako_fonts.dart';

/// ログイン前の画面（案6）の土台。
/// 画面の全面に紙（key: hako_column）を敷く。上下に色の帯（全幅）。
/// 縦にスクロールし、中身が短いときは下の帯が画面の下に来る。
/// 広い画面で中身を読みやすい幅にしたいときは、中身を [HakoContent] で包む。
class HakoPage extends StatelessWidget {
  const HakoPage({super.key, required this.child});

  /// 色の帯の間に入る中身
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.backdrop,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: ColoredBox(
                  key: const Key('hako_column'),
                  color: BrandColors.paper,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const ColorStrip(), child],
                      ),
                      const ColorStrip(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 中身を読みやすい幅（430 以下）にして中央に置く。紙や色の帯は全幅のまま
class HakoContent extends StatelessWidget {
  const HakoContent({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 430;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 6色の帯（高さ 10。hall1〜hall6 を等分）。装飾なので読み上げない
class ColorStrip extends StatelessWidget {
  const ColorStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (final color in BrandColors.halls)
              Expanded(child: ColoredBox(color: color)),
          ],
        ),
      ),
    );
  }
}

/// 丸い枠のボタン（「ログイン」「戻る」など）
class HakoPill extends StatelessWidget {
  const HakoPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool small;

  /// 文字の大きさ。省略時は 14（small は 13）
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 18,
          vertical: small ? 3 : 0,
        ),
        foregroundColor: BrandColors.ink,
        side: const BorderSide(color: BrandColors.ink, width: 2),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.padded,
        overlayColor: BrandColors.ink,
      ),
      child: Text(
        label,
        style: HakoFonts.jp(
          size: fontSize ?? (small ? 13 : 14),
          weight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

/// 墨の大きなボタン（送信など）。busy のときは黄色のくるくるを出し、押せない
class HakoPrimaryButton extends StatelessWidget {
  const HakoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Opacity(
        opacity: (!enabled && !busy) ? 0.5 : 1,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: BrandColors.ink,
              disabledBackgroundColor: BrandColors.ink,
              foregroundColor: BrandColors.hall3,
              disabledForegroundColor: BrandColors.hall3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              overlayColor: BrandColors.hall3,
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: BrandColors.hall3,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: HakoFonts.jp(
                      size: 18,
                      weight: FontWeight.w700,
                      color: BrandColors.hall3,
                      height: 1.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 切り替えの札（ログイン／新規登録）。横に並べるときは Expanded で包む
class HakoTab extends StatelessWidget {
  const HakoTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : BrandColors.ink;
    final bg = selected ? BrandColors.ink : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      excludeSemantics: true,
      label: label,
      onTap: onPressed,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: BrandColors.ink, width: 2),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: HakoFonts.jp(
                    size: 16,
                    weight: FontWeight.w700,
                    color: fg,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 入力欄の中の文字（TextFormField の `style:` に渡す）
TextStyle hakoInputTextStyle() => HakoFonts.jp(size: 16, height: 1.4);

/// 入力欄の見た目（白・枠 2px 墨・角丸 4。フォーカス中は青の 4px）。
/// TextFormField には `style: hakoInputTextStyle()` と `cursorColor: BrandColors.ink` も渡す
InputDecoration hakoInputDecoration({String? helperText, Widget? suffixIcon}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: false,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    helperText: helperText,
    helperMaxLines: 3,
    helperStyle: HakoFonts.jp(size: 13, height: 1.4),
    errorMaxLines: 3,
    errorStyle: HakoFonts.jp(
      size: 13,
      color: BrandColors.errorText,
      height: 1.4,
    ),
    hintStyle: HakoFonts.jp(size: 16, height: 1.4),
    suffixIcon: suffixIcon,
    suffixIconColor: BrandColors.ink,
    border: border(BrandColors.ink, 2),
    enabledBorder: border(BrandColors.ink, 2),
    disabledBorder: border(BrandColors.ink, 2),
    focusedBorder: border(BrandColors.hall5, 4),
    errorBorder: border(BrandColors.errorText, 2),
    focusedErrorBorder: border(BrandColors.hall5, 4),
  );
}

/// 入力欄の上のラベル（前の欄から 14、欄の上 4 離す）
Widget hakoFieldLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Text(
      text,
      style: HakoFonts.jp(size: 14, weight: FontWeight.w700, height: 1.4),
    ),
  );
}
