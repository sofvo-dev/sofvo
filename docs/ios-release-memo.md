# iOS / Android 審査提出メモ（成功済み設定）

## 成功した設定ファイル

### 1. Appfile（Apple ID）
```ruby
# ios/fastlane/Appfile
app_identifier("com.sofvo.app")
apple_id(ENV["APPLE_ID"] || "info@sofvo.com")
team_id(ENV["APPLE_TEAM_ID"] || "")
```

### 2. Fastfile（全自動リリース）
```ruby
# ios/fastlane/Fastfile
lane :release do
  sh("cd ../.. && git stash; git pull origin main --rebase; git stash pop || true")
  sh("cd ../.. && flutter clean")
  sh("cd ../.. && flutter pub get")
  sh("rm -rf Pods Podfile.lock && pod install --repo-update")
  sh("cd ../.. && flutter build ios --release")

  build_app(
    workspace: "Runner.xcworkspace",
    scheme: "Runner",
    export_method: "app-store",
    output_directory: "../build/ios",
    output_name: "Sofvo.ipa"
  )

  upload_to_app_store(
    skip_metadata: true,
    skip_screenshots: true,
    precheck_include_in_app_purchases: false,
    submit_for_review: true,
    automatic_release: true
  )
end
```

### 3. Xcodeプロジェクト（DEVELOPMENT_TEAM）
`ios/Runner.xcodeproj/project.pbxproj` の3箇所（Debug/Profile/Release）:
```
DEVELOPMENT_TEAM = TLVKKC442B;
```

### 4. バージョン（2026/04/05 時点）
```yaml
# pubspec.yaml
version: 1.0.4+17
```

---

## 審査提出コマンド

### iOS（Macで1コマンド）
```bash
cd ~/Desktop/sofvo/ios
fastlane release
```
git pull → flutter clean → build → App Store Connect アップロード → 審査提出まで全自動。

### Android（GitHub Actions）
1. GitHub → Actions タブ
2. 「Build Android AAB」を選択
3. 「Run workflow」→「Google Play 製品版にアップロード」にチェック
4. 実行 → 全自動

---

## 次回バージョンアップ時
```bash
# pubspec.yaml の version を更新してからmainにマージ
# 例: 1.0.4+17 → 1.0.5+18
```

## トラブルシュート
- **未コミット変更エラー**: Fastfileが自動で `git stash` → `git stash pop` するので対応済み
- **署名エラー**: `DEVELOPMENT_TEAM = TLVKKC442B` が project.pbxproj に入っていることを確認
- **Apple IDエラー**: Appfileが `info@sofvo.com` になっていることを確認
