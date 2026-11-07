# ArchivoHako（案6の英字ラベル用の書体）

- もとの書体: Archivo（The Archivo Project Authors。SIL Open Font License 1.1。ライセンス全文は `OFL-Archivo.txt`）
- 作り方: Archivo の可変フォント（Latin の範囲）から、幅と太さを固定した静的なフォントを3つ取り出し、名前を `ArchivoHako` に付け替えた（OFL に沿った改変）。
  - `ArchivoHako-Bold110.ttf` … 太さ 700・幅 110%（日付の数字）
  - `ArchivoHako-ExtraBold125.ttf` … 太さ 800・幅 125%（「HALL 01」などの英字ラベル）
  - `ArchivoHako-Black125.ttf` … 太さ 900・幅 125%（大きな数字 01〜06）
- 理由: Flutter の google_fonts では、Archivo の「幅」の軸が使えず、案6の横に広い形が出せないため。
- 文字の範囲: Latin（英字・数字・基本の記号）だけ。矢印「→」などは入っていない。
