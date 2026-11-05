#!/usr/bin/env bash
# コンテナ作成後に1回だけ実行される
#   - tmux: agent team を画面分割で表示したいとき用
#   - Java: Firestore エミュレータ（ルールのテスト）に必要
#   - Claude Code 本体
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends tmux default-jre-headless
rm -rf /var/lib/apt/lists/*

if ! command -v claude > /dev/null 2>&1 && [ ! -x /root/.local/bin/claude ]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

/root/.local/bin/claude --version || true
java -version || true
