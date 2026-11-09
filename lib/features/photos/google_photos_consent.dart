import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/brand_colors.dart';
import '../../theme/hako_fonts.dart';
import '../memory/ticket/ticket_widgets.dart';

/// 同意の説明に出す箇条書き（計画書 4.11）
const googlePhotosConsentItems = [
  '写真を読み取るだけです。変更や削除はしません。',
  'Googleフォトの画面で、あなたが選んだ写真だけを使います。ライブラリ全体は見ません。',
  '選んだ写真は、AI（Gemini）に送って、よく写っている写真を選びます。',
  '記録に入れた写真だけを、おしあしに保存します。',
  'やめたいときは、Googleアカウントの設定（Googleのサービスにアクセスできるアプリ）から解除できます。',
];

/// 同意のダイアログ（4.4.2）。このタブで最初に「つなぐ」を押したときだけ出す。
///
/// 「つなぐ」を押したら、**そのボタンの処理の最初に** [onConsent] を呼ぶ
/// （認可のポップアップを、ブラウザに止められないため。await を挟まない）。
/// 「今はしない」は閉じるだけ。Esc でも閉じる
Future<void> showGooglePhotosConsent(
  BuildContext context, {
  required VoidCallback onConsent,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: BrandColors.ink.withValues(alpha: 0.45),
    // 動きを減らす設定のときは、出入りの動きを止める（4.10）
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (dialogContext) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(dialogContext).maybePop(),
      },
      child: GooglePhotosConsentDialog(
        onYes: () {
          // 最初に認可を始める（ポップアップを開く）。そのあとでダイアログを閉じる
          onConsent();
          Navigator.of(dialogContext).pop();
        },
        onNo: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  );
}

/// 同意のダイアログの中身（枠 2px・角丸 18・影 `6px 6px 0`）
class GooglePhotosConsentDialog extends StatelessWidget {
  const GooglePhotosConsentDialog({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Googleフォトとつなぎますか？',
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: BrandColors.ink, offset: Offset(6, 6)),
              ],
            ),
            child: Container(
              key: const Key('google_photos_consent'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BrandColors.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: BrandColors.ink, width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Googleフォトとつなぎますか？',
                        style: HakoFonts.jp(
                          size: 18,
                          weight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final item in googlePhotosConsentItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '・',
                              style: HakoFonts.jp(size: 14, height: 1.8),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: HakoFonts.jp(size: 14, height: 1.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TicketButton(
                            key: const Key('google_photos_consent_no'),
                            label: '今はしない',
                            onPressed: onNo,
                            wide: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TicketButton(
                            key: const Key('google_photos_consent_yes'),
                            label: 'つなぐ',
                            autofocus: true,
                            kind: TicketButtonKind.green,
                            onPressed: onYes,
                            wide: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
