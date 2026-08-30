#!/usr/bin/env bash
# Mac のディスクを安全に片付けるスクリプト。
#
#   ./scripts/mac-disk-cleanup.sh          # 調べるだけ（何も消さない）
#   ./scripts/mac-disk-cleanup.sh --clean  # 安全なものだけ消す
#
# 2026-08-30 に空き 16GB → 195GB まで回復したときの手順をそのまま script 化した。
# 最大の原因は ~/Library/Caches/Adobe（このとき 138GB）。
# 消してもアプリが作り直すだけなので、半年〜1年ごとに実行してよい。
#
# ここで消すのは「消えても作り直されるキャッシュ」と「アプリが無いのに残った抜け殻」だけ。
# 書類・写真・メール・メモ・ブックマーク・パスワードには一切触れない。
set -uo pipefail

CLEAN=0
[ "${1:-}" = "--clean" ] && CLEAN=1

free_space() { df -h /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}'; }

BEFORE=$(free_space)
echo "現在の空き容量: $BEFORE"
echo

# path|説明
TARGETS=(
  "$HOME/Library/Caches/Adobe|Adobe のキャッシュ（毎回ここが一番大きい）"
  "$HOME/Library/Application Support/Adobe/Common/Media Cache Files|After Effects / Premiere のメディアキャッシュ"
  "$HOME/Library/Application Support/Adobe/Common/Media Cache|After Effects / Premiere のメディアキャッシュ（索引）"
  "$HOME/Library/Caches/Google/Chrome|Chrome のキャッシュ（履歴やパスワードではない）"
  "$HOME/Library/Caches/CocoaPods|CocoaPods のキャッシュ"
  "$HOME/Library/Developer/Xcode/DerivedData|Xcode のビルド中間ファイル"
  "$HOME/Library/Developer/Xcode/Archives|Xcode の古い Archive（審査提出は GitHub Actions なので不要）"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport|iPhone を繋いだときに作られるデータ"
  "$HOME/Library/Developer/CoreSimulator/Caches|iOS シミュレータのキャッシュ"
  "$HOME/Library/Caches/com.apple.dt.Xcode|Xcode のキャッシュ"
  "$HOME/.Trash|ゴミ箱"
)

total_found=0
for entry in "${TARGETS[@]}"; do
  path="${entry%%|*}"
  label="${entry##*|}"
  [ -e "$path" ] || continue
  size=$(du -sh "$path" 2>/dev/null | cut -f1)
  total_found=$((total_found + 1))
  if [ "$CLEAN" = "1" ]; then
    if [ "$path" = "$HOME/.Trash" ]; then
      # ゴミ箱はフォルダ自体を消さず中身だけ空にする（Finder が使うため）
      rm -rf "$path"/* "$path"/.[!.]* 2>/dev/null
    else
      rm -rf "$path" 2>/dev/null
    fi
    printf '  削除  %6s  %s\n' "$size" "$label"
  else
    printf '  %6s  %s\n' "$size" "$label"
  fi
done

if [ "$total_found" = "0" ]; then
  echo "  片付けるものはありませんでした（すでにきれいです）"
fi

# 使えなくなった iOS シミュレータ（Xcode 更新で残る）
if command -v xcrun >/dev/null 2>&1 && [ "$CLEAN" = "1" ]; then
  xcrun simctl delete unavailable >/dev/null 2>&1 && echo "  削除  古い iOS シミュレータ"
fi

# Homebrew の古いパッケージ
if command -v brew >/dev/null 2>&1 && [ "$CLEAN" = "1" ]; then
  brew cleanup --prune=all >/dev/null 2>&1 && echo "  削除  Homebrew の古いキャッシュ"
fi

# OS アップデートの残骸（root 所有なので sudo が要る）
if compgen -G "/Users/Shared/*Relocated Items*" >/dev/null; then
  if [ "$CLEAN" = "1" ]; then
    echo
    echo "OS アップデートの残骸を消します（パスワードを聞かれます。入力しても画面には出ません）"
    sudo rm -rf /Users/Shared/*Relocated\ Items* && echo "  削除  Previously Relocated Items"
  else
    echo "  （少量）OS アップデートの残骸 /Users/Shared/Previously Relocated Items*"
  fi
fi

echo
if [ "$CLEAN" = "1" ]; then
  echo "空き容量: $BEFORE → $(free_space)"
else
  echo "上のものを実際に消すには: ./scripts/mac-disk-cleanup.sh --clean"
fi

cat <<'NOTE'

── ここは消さないこと ──────────────────────
  ~/Library/Application Support/Google/Chrome   ブックマーク・保存パスワード
  ~/Library/Containers/com.apple.Notes          「メモ」の中身そのもの
  ~/Library/Mail                                 メール本体
  ~/Library/Metadata                             Spotlight の索引（消すと Mac が数時間重くなるだけ）
  ~/Library/CloudStorage                         Google ドライブの入口（du では大きく見えるが実体はクラウド）
  /Library, /System                              macOS 本体
NOTE
