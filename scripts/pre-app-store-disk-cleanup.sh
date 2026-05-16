#!/usr/bin/env bash
# 審査提出（fastlane release）の前に、Mac の Xcode まわりの不要ファイルを削除する。
# 削除しても次回ビルドで再生成されるものだけ対象（提出用 IPA には影響しない）。
#
# 使い方（Mac）:
#   cd ~/Desktop/sofvo
#   ./scripts/pre-app-store-disk-cleanup.sh
set -euo pipefail

ARCHIVES="${HOME}/Library/Developer/Xcode/Archives"
DERIVED="${HOME}/Library/Developer/Xcode/DerivedData"

freed_label() {
  local before="$1"
  local after="$2"
  if [[ -n "$before" && -n "$after" ]]; then
    echo "  → 削除前 ${before} / 削除後 ${after}"
  fi
}

rm_dir_contents() {
  local dir="$1"
  local label="$2"
  if [[ ! -d "$dir" ]]; then
    echo "⊘ ${label}: フォルダなし（スキップ）"
    return 0
  fi
  local before
  before="$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")"
  # zsh でも空ディレクトリでエラーにしない
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  local after
  after="$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "?")"
  echo "✓ ${label}"
  freed_label "$before" "$after"
}

echo "== 審査提出前ディスク整理（Xcode）=="
echo "対象: 古い Archive / DerivedData（再ビルドで再生成されます）"
echo ""

rm_dir_contents "$ARCHIVES" "Xcode Archives"
rm_dir_contents "$DERIVED" "DerivedData"

echo ""
echo "完了。このあと git pull → flutter clean → fastlane release で提出してください。"
echo "（まだ Xcode が大きい場合のみ、別途 iOS DeviceSupport の古いフォルダを手動削除）"
