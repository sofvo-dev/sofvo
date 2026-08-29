#!/usr/bin/env bash
# Cloud Functions の「誰でも呼べる権限（allUsers invoker）」が抜けている関数を
# 検出して修復するスクリプト。
#
#   ./scripts/fix-function-invokers.sh          # 調べるだけ（変更しない）
#   ./scripts/fix-function-invokers.sh --fix    # 抜けている関数に権限を付ける
#
# 背景: 新規作成された Cloud Functions は既定で非公開。デプロイ時の権限付与が
# 失敗すると、関数は存在するのに Google の入口で 403 になり、アプリには
# 「UNAUTHENTICATED」と表示される。新しい関数を追加したら実行すること。
set -uo pipefail

PROJECT="${PROJECT:-sofvo-19d84}"
REGION="${REGION:-us-central1}"
FIX=0
[ "${1:-}" = "--fix" ] && FIX=1

command -v gcloud >/dev/null || {
  echo "gcloud が必要です: https://cloud.google.com/sdk/docs/install"
  exit 1
}

echo "プロジェクト: $PROJECT / リージョン: $REGION"
echo "HTTPS 関数を取得中..."

FUNCS=$(gcloud functions list \
  --project="$PROJECT" --regions="$REGION" \
  --filter="httpsTrigger.url:*" \
  --format="value(name)" | sed 's#.*/##')

if [ -z "$FUNCS" ]; then
  echo "HTTPS 関数が見つかりませんでした（gcloud のログイン状態を確認してください）"
  exit 1
fi

missing=0
total=0
for f in $FUNCS; do
  total=$((total + 1))
  policy=$(gcloud functions get-iam-policy "$f" \
    --project="$PROJECT" --region="$REGION" --format=json 2>/dev/null)
  if echo "$policy" | grep -q '"allUsers"'; then
    printf '  OK   %s\n' "$f"
  else
    missing=$((missing + 1))
    printf '  NG   %s  ← 公開権限なし（403 になる）\n' "$f"
    if [ "$FIX" = "1" ]; then
      if gcloud functions add-iam-policy-binding "$f" \
        --project="$PROJECT" --region="$REGION" \
        --member=allUsers --role=roles/cloudfunctions.invoker >/dev/null 2>&1; then
        printf '       → 修復しました\n'
      else
        printf '       → 修復に失敗（自分の権限不足の可能性）\n'
      fi
    fi
  fi
done

echo "----"
echo "HTTPS 関数 $total 個中、公開権限なし $missing 個"
if [ "$missing" -gt 0 ] && [ "$FIX" = "0" ]; then
  echo "修復するには: ./scripts/fix-function-invokers.sh --fix"
fi
