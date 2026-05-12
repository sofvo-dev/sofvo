#!/usr/bin/env bash
# Xcode / Flutter 周りのキャッシュ・ビルド成果物を削除してディスクを空ける。
# 使い方:
#   ./scripts/clean-xcode-disk.sh                    # プロジェクト内のみ（安全）
#   ./scripts/clean-xcode-disk.sh --derived          # DerivedData を全削除（対話確認）
#   ./scripts/clean-xcode-disk.sh --simulators       # 利用不可シミュレータのみ
#   ./scripts/clean-xcode-disk.sh --derived --simulators  # 両方
set -euo pipefail

DO_DERIVED=false
DO_SIM=false
for arg in "$@"; do
  case "$arg" in
    --derived) DO_DERIVED=true ;;
    --simulators) DO_SIM=true ;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# //' | head -12
      exit 0
      ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Sofvo プロジェクト内（再生成されるもの）=="
if command -v flutter >/dev/null 2>&1; then
  flutter clean
else
  echo "flutter が PATH にないためスキップ。手動: cd $ROOT && flutter clean"
fi
rm -rf build .dart_tool
rm -rf ios/build ios/Pods ios/.symlinks ios/Flutter/Flutter.framework ios/Flutter/Flutter.podspec 2>/dev/null || true
echo "削除: build/, .dart_tool/, ios/build/, ios/Pods/, ios/.symlinks 等"
echo "次回 iOS ビルド前: cd ios && pod install --repo-update"

if [[ "$DO_DERIVED" == true ]]; then
  DD="$HOME/Library/Developer/Xcode/DerivedData"
  if [[ -d "$DD" ]]; then
    echo ""
    echo "DerivedData 使用量: $(du -sh "$DD" 2>/dev/null | cut -f1)"
    read -r -p "DerivedData をすべて削除しますか？ [y/N] " a
    if [[ "$a" =~ ^[yY]$ ]]; then
      rm -rf "${DD:?}"/*
      echo "DerivedData を空にしました。"
    else
      echo "キャンセルしました。"
    fi
  else
    echo "DerivedData ディレクトリがありません: $DD"
  fi
fi

if [[ "$DO_SIM" == true ]]; then
  if command -v xcrun >/dev/null 2>&1; then
    echo ""
    echo "利用不可のシミュレータを削除します…"
    xcrun simctl delete unavailable 2>/dev/null || true
    echo "完了。"
  fi
fi

echo ""
echo "== 手動で空けられる主な場所（参考）=="
echo "  - Organizer の古い Archive: Xcode → Window → Organizer"
echo "  - 古い実機サポート: ~/Library/Developer/Xcode/iOS DeviceSupport/"
echo "  - SwiftPM: ~/Library/Caches/org.swift.swiftpm/"
echo "  - CocoaPods: ~/Library/Caches/CocoaPods/"
