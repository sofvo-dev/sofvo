#!/usr/bin/env bash
# Mac: 審査提出までをこの1本で実行（ディスク整理 → main 最新化 → fastlane release）
#
# 使い方:
#   cd ~/Desktop/sofvo
#   ./scripts/app-store-release.sh
#
# fastlane release 内で flutter clean / pod install / IPA ビルド / App Store 提出まで行う。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== 1/3 ディスク整理（Xcode Archives / DerivedData）=="
"$ROOT/scripts/pre-app-store-disk-cleanup.sh"

echo ""
echo "== 2/3 コード最新化（main）=="
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo "未コミットの変更があります。stash してから pull します…"
  git stash push -u -m "app-store-release-$(date +%Y%m%d-%H%M)" || true
  STASHED=1
else
  STASHED=0
fi

git checkout main
git pull origin main --rebase

if [[ "$STASHED" == 1 ]]; then
  echo "stash を戻します（コンフリクトしたら手動で解消）…"
  git stash pop || true
fi

echo ""
echo "== 3/3 fastlane release（ビルド・アップロード・審査提出）=="
cd "$ROOT/ios"
exec fastlane release
