# GitHub Actions から iOS を審査提出する（Mac不要）

Android と同じように、GitHub の Actions タブから iOS のビルド → App Store Connect
アップロード → 審査提出まで実行できるようにした手順。

- ワークフロー: `.github/workflows/ios-release.yml`
- fastlane レーン: `ios/fastlane/Fastfile` の `ci_beta` / `ci_release`
- **このリポジトリは public なので macOS ランナーは無料**（private だと Linux の10倍の分数を消費する）

## 使い方（設定が済んだあと）

1. GitHub → **Actions** タブ
2. 「**Build iOS & Submit to App Store**」を選択
3. **Run workflow** をクリック
4. 提出先を選ぶ
   - `ci_beta` … TestFlight にアップロードのみ（審査に出さない。まず動作確認したいとき）
   - `ci_release` … App Store Connect にアップロードして**審査提出まで**行う
5. `ci_release` の場合は「このバージョンの最新情報」を入力（空なら既定文）

Mac での `./scripts/app-store-release.sh` は今までどおり使える。CI はその代替であって置き換えではない。

## 初回だけ必要な準備

以下を GitHub の **Settings → Secrets and variables → Actions → New repository secret** に登録する。
（public リポジトリでも Secrets の中身は他人からは見えない。ログにも出力していない）

### 1. App Store Connect API キー（Apple ID とパスワードの代わり）

2要素認証を回避するため、Apple ID ではなく API キーで認証する。

1. [App Store Connect](https://appstoreconnect.apple.com/) → **ユーザーとアクセス** → **統合** → **App Store Connect API**
2. **キーを生成**（アクセス権: **App Manager**）
3. 生成後に表示される値と、一度だけダウンロードできる `.p8` ファイルを控える

| Secret 名 | 値 |
|---|---|
| `ASC_KEY_ID` | キーID（例: `ABCD123456`） |
| `ASC_ISSUER_ID` | ページ上部の Issuer ID（UUID 形式） |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` の結果 |

### 2. 配布用証明書（.p12）

Mac の**キーチェーンアクセス**で、`Apple Distribution: ...` の証明書を秘密鍵ごと選択 →
右クリック → **書き出す** → `.p12` 形式で保存（任意のパスワードを設定）。

| Secret 名 | 値 |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | `base64 -i dist.p12 \| pbcopy` の結果 |
| `IOS_DIST_CERT_PASSWORD` | 書き出し時に設定したパスワード |

### 3. プロビジョニングプロファイル

現在の Xcode は「Automatically manage signing」だが、CI では手動署名を使うため
App Store 用のプロファイルを明示的に作る。

1. [Apple Developer](https://developer.apple.com/account/resources/profiles/list) → **Profiles** → **+**
2. **App Store Connect**（Distribution）を選択
3. App ID は `com.sofvo.app`、証明書は上で書き出したものを選ぶ
4. 名前を付けて生成し `.mobileprovision` をダウンロード

| Secret 名 | 値 |
|---|---|
| `IOS_PROFILE_BASE64` | `base64 -i xxx.mobileprovision \| pbcopy` の結果 |
| `IOS_PROFILE_NAME` | 手順4で付けたプロファイル名（そのままの文字列） |
| `APPLE_TEAM_ID` | `TLVKKC442B` |

## 注意

- **バージョン番号は事前に上げておくこと**。`pubspec.yaml` の `version:`（`1.0.43+57` の
  `+` の前がバージョン、後ろがビルド番号）。同じビルド番号は再アップロードできない
- 証明書は**1年で失効**する。失効したら Secrets の `IOS_DIST_CERT_P12_BASE64` と
  プロファイルを更新する
- スクリーンショットは CI から更新しない（`skip_screenshots: true`）。説明文・キーワードは
  `ios/fastlane/metadata/ja/` の内容が自動反映される
- 失敗したときは Actions のログを見る。ビルドできた IPA は成果物として
  ダウンロードできるので、原因切り分けに使える
