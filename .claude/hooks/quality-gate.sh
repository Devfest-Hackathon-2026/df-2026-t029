#!/usr/bin/env bash
# 品質ゲート（Claude Code の TaskCompleted フック）
#
# タスクが「完了」になる直前に実行される。
#   1. flutter analyze
#   2. flutter test（test/ に *_test.dart があるとき）
#   3. Firestore ルールのテスト（test_rules/ を用意したとき）
# どれかが失敗したら exit 2 で完了を差し戻し、stderr の内容をエージェントに返す。
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$PROJECT_DIR" || exit 0

# フックの入力（JSON）は使わないので読み捨てる
cat > /dev/null 2>&1 || true

note() { echo "[quality-gate] $*" >&2; }

fail() {
  {
    echo "品質ゲートで完了を差し戻しました: $1"
    echo "原因を直してから、もう一度タスクを完了にしてください。"
    echo "原因が自分の担当外のファイルなら、自分では直さず、その担当者とリーダーに SendMessage で知らせてください。"
    echo "----- 出力 -----"
    echo "$2"
  } >&2
  exit 2
}

if ! command -v flutter > /dev/null 2>&1; then
  note "flutter が見つからないため、チェックを省略しました。Dev Container の中で Claude Code を起動してください。"
  exit 0
fi

# 複数のチームメイトがほぼ同時に完了しても、チェックを1つずつ順に実行する
if command -v flock > /dev/null 2>&1; then
  exec 9> /tmp/oshiashi-quality-gate.lock
  flock -w 900 9 || note "ロックを取得できなかったため、そのまま実行します。"
fi

# 1. 静的解析（info も含めて 0 件であること）
ANALYZE_OUT="$(flutter analyze 2>&1)"
if [ $? -ne 0 ]; then
  fail "flutter analyze で指摘があります。" "$(printf '%s\n' "$ANALYZE_OUT" | tail -n 80)"
fi

# 2. テスト
if [ -n "$(find test -name '*_test.dart' -print -quit 2> /dev/null)" ]; then
  TEST_OUT="$(flutter test --reporter expanded 2>&1)"
  if [ $? -ne 0 ]; then
    # 成功したテストの進捗行を除き、失敗（[E]）とエラーの詳細だけを返す
    DETAIL="$(printf '%s\n' "$TEST_OUT" | awk '/^[0-9]+:[0-9]+ \+[0-9]+/ && !/\[E\]/ { next } { print }' | head -n 150)"
    [ -z "$DETAIL" ] && DETAIL="$(printf '%s\n' "$TEST_OUT" | tail -n 80)"
    fail "flutter test で失敗したテストがあります。" "$DETAIL"
  fi
fi

# 3. Firestore ルールのテスト（test_rules/ を用意した後だけ）
if [ -f test_rules/package.json ]; then
  if ! command -v firebase > /dev/null 2>&1 || ! command -v java > /dev/null 2>&1; then
    note "firebase または java が無いため、Firestore ルールのテストを省略しました。"
  elif [ ! -d test_rules/node_modules ]; then
    note "test_rules/node_modules が無いため、Firestore ルールのテストを省略しました（npm --prefix test_rules install を実行してください）。"
  else
    RULES_OUT="$(firebase emulators:exec --only firestore --project demo-oshiashi "npm --prefix test_rules test" 2>&1)"
    if [ $? -ne 0 ]; then
      fail "Firestore ルールのテストに失敗しました。" "$(printf '%s\n' "$RULES_OUT" | tail -n 80)"
    fi
  fi
fi

exit 0
