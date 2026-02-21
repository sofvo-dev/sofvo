#!/bin/bash
set -e

# ============================================
# Sofvo デプロイスクリプト
# 使い方: ./deploy.sh [web|android|ios|all]
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "\n${GREEN}===> $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# 引数チェック
TARGET=${1:-all}

# Flutter依存関係を更新
print_step "依存関係を更新中..."
flutter pub get

# ============================================
# Web デプロイ
# ============================================
deploy_web() {
  print_step "Flutter Web をビルド中..."
  flutter build web --release

  print_step "ランディングページを統合中..."
  # website/ のファイルを build/web/ にコピー（Flutter の index.html は /app/ 用）
  # ランディングページを build/web/lp/ に配置
  mkdir -p build/web/lp
  cp website/index.html build/web/lp/
  cp website/terms.html build/web/
  cp website/privacy.html build/web/
  cp website/contact.html build/web/
  cp website/404.html build/web/

  print_step "Firebase (Hosting + Firestore ルール＆インデックス) にデプロイ中..."
  firebase deploy --only hosting,firestore

  echo -e "\n${GREEN}✓ Web デプロイ完了！${NC}"
  echo "  アプリ: https://sofvo-19d84.web.app/"
  echo "  LP:     https://sofvo-19d84.web.app/lp/"
  echo "  規約:   https://sofvo-19d84.web.app/terms.html"
  echo "  ポリシー: https://sofvo-19d84.web.app/privacy.html"
}

# ============================================
# Android デプロイ
# ============================================
deploy_android() {
  # キーストア確認
  if [ ! -f "android/app/sofvo-release-key.jks" ]; then
    print_warn "リリース用キーストアが見つかりません。作成します..."
    echo ""
    echo "以下の情報を入力してください："
    keytool -genkey -v \
      -keystore android/app/sofvo-release-key.jks \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -alias sofvo-key

    # key.properties作成
    echo "キーストアのパスワードを再入力してください："
    read -s KEY_PASSWORD
    cat > android/key.properties << KEYEOF
storePassword=$KEY_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=sofvo-key
storeFile=sofvo-release-key.jks
KEYEOF

    print_warn "android/key.properties を作成しました"
    print_warn "android/app/sofvo-release-key.jks を安全な場所にバックアップしてください！"
  fi

  print_step "Android App Bundle をビルド中..."
  flutter build appbundle --release

  APP_BUNDLE="build/app/outputs/bundle/release/app-release.aab"

  if [ -f "$APP_BUNDLE" ]; then
    echo -e "\n${GREEN}✓ Android ビルド完了！${NC}"
    echo "  AAB: $APP_BUNDLE"
    echo ""
    echo "  次のステップ:"
    echo "  1. Google Play Console (https://play.google.com/console/) にログイン"
    echo "  2. アプリを作成 → 内部テストトラック → AABファイルをアップロード"
    echo "  3. ストア掲載情報を入力して審査に提出"
  else
    print_error "ビルドに失敗しました"
    exit 1
  fi
}

# ============================================
# iOS デプロイ
# ============================================
deploy_ios() {
  if [[ "$(uname)" != "Darwin" ]]; then
    print_error "iOS ビルドは macOS でのみ実行できます"
    exit 1
  fi

  print_step "iOS をビルド中..."
  flutter build ios --release

  print_step "Xcode Archive を作成中..."
  cd ios
  xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath ../build/ios/Runner.xcarchive \
    archive
  cd ..

  ARCHIVE="build/ios/Runner.xcarchive"

  if [ -d "$ARCHIVE" ]; then
    echo -e "\n${GREEN}✓ iOS ビルド完了！${NC}"
    echo "  Archive: $ARCHIVE"
    echo ""
    echo "  次のステップ:"
    echo "  1. Xcode で $ARCHIVE を開く"
    echo "  2. 'Distribute App' → 'App Store Connect' を選択"
    echo "  3. アップロード完了後、App Store Connect で審査に提出"
    echo ""
    echo "  または以下のコマンドで自動アップロード:"
    echo "  xcodebuild -exportArchive -archivePath $ARCHIVE -exportPath build/ios/export -exportOptionsPlist ios/ExportOptions.plist"
  else
    print_error "ビルドに失敗しました"
    exit 1
  fi
}

# ============================================
# 全てデプロイ
# ============================================
deploy_all() {
  deploy_web
  deploy_android
  deploy_ios
}

# 実行
case $TARGET in
  web)     deploy_web ;;
  android) deploy_android ;;
  ios)     deploy_ios ;;
  all)     deploy_all ;;
  *)
    echo "使い方: ./deploy.sh [web|android|ios|all]"
    echo ""
    echo "  web     - Flutter Web + Firebase Hosting デプロイ"
    echo "  android - Android AAB ビルド"
    echo "  ios     - iOS Archive ビルド"
    echo "  all     - 全プラットフォーム"
    exit 1
    ;;
esac
