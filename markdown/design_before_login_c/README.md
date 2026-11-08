# 紹介ページ（案C 改）の見本と参照画像

仕様書: `markdown/feature_before_login_c_plan.md`

## 見本

- `oshiashi_C_v3.html` — ユーザーが渡した**元の HTML**（変更なし）。Chrome で開くと実物が見られる（書体は端末のもの。Mac なら Hiragino Sans）。
- `oshiashi_C_v3_fixed.html` — 元の HTML の CSS の食い違いを**2つだけ**直した版。**仕様書の数値と参照画像は、こちらを正にしている**（仕様書 5.1）。
  1. `header{padding:28px 0 0}` が `.wrap{padding:0 24px}` に負けて効いていなかった → `header.wrap{padding-top:28px}` で効かせた。
  2. 幅 520px 以下の `.wrap{padding:0 18px}` が、`.hero`・`.sec-title` の上下の余白を 0 にしていた → `padding-left`・`padding-right` だけ 18px にした。
- どちらの HTML も見本であって、アプリには入れない（Dart で作る）。

## 参照画像（`shots/`）

BIZ UDPGothic（本文）と Archivo（英字・数字）で描いて撮ったもの（アプリの書体に近づけるため）。**全面の撮影で、いちばん上に「案C 改」のバッジ（高さ 32.4）が写っている**。本番にバッジは無いので、実際の位置は画像の位置から 32.4 を引く。

| ファイル | 中身 |
|---|---|
| `c3_390_1.png`〜`c3_390_4.png` | 幅 390（スマホ）。上から 1350px ずつ。1: ヘッダー・最初の画面・PROBLEM 01 ／ 2: FLOW・PROBLEM 02・SOLUTION ／ 3: 6つのハコ（1列）・FAQ ／ 4: FAQ・CTA |
| `c3_1000_1.png`・`c3_1000_2.png` | 幅 1000（PC）。上から 1750px ずつ |
| `c3_640_tiles.png` | 幅 640。6つのハコが 2列 |
| `c3_1440_tiles.png` | 幅 1440。6つのハコが全幅で 3列 |
| `c3_faq_open_390.png` | 幅 390。FAQ の1つ目と3つ目を開いたところ |
| `c3_orig_390_top.png` | **元の HTML のまま**の幅 390 の上のほう（余白が消えて詰まっている。仕様書 5.1 の案B） |

- `measure.json` — 修正版を、幅 360 / 390 / 520 / 521 / 640 / 760 / 761 / 1000 / 1440px で測った値。区画ごとに `[幅, 高さ, ページ上端からの位置]`（バッジ込みなので、位置から 32.4 を引く）。
