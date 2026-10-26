# リリースと配布

choco-browser は GitHub Releases で DMG を配布し、`site/` の紹介サイトを GitHub Pages で公開します。

## 構成

| 何を | どこで |
|---|---|
| DMG 作成 | `scripts/make-dmg.sh`（`task dmg`） |
| リリース公開 | `.github/workflows/release.yml`（`v*` タグの push で起動） |
| 紹介サイト | `site/`（日本語 `index.html`、英語 `en/index.html`）、`.github/workflows/pages.yml` で公開 |
| 仮アイコン | `scripts/make-icon.sh`（`AppSupport/AppIcon.icns` と `site/assets/icon.png` を生成） |

配布物は Apple Silicon（arm64）専用です。現在のビルド環境は arm64 のみで、Intel 向けの universal ビルドはしていません。

## ローカルで DMG を作る

```sh
VERSION=0.1.0 BUILD_NUMBER=1 ./scripts/make-dmg.sh
```

`build/choco-browser-0.1.0.dmg` と `build/choco-browser-0.1.0.dmg.sha256` ができます。`VERSION` を省略すると `AppSupport/Info.plist` の値を使います。

## リリースする

1. `AppSupport/Info.plist` の既定バージョンを必要なら更新してコミットする
2. タグを打って push する

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. Actions の Release が、バージョン付きの DMG と `.sha256`、固定名の `choco-browser.dmg` と `choco-browser.dmg.sha256` を Releases に添付する（サイトの検証手順は固定名のチェックサムを使う）
4. サイトの「ダウンロード」ボタンは `releases/latest/download/choco-browser.dmg` を指すため、Release を公開すると最新版に切り替わる

注意: `releases/latest` は pre-release を除外します。サイトのリンクを生かすため、α版でも pre-release にはしません。

## 署名と公証

既定は ad-hoc 署名です。この状態の DMG は Gatekeeper に拒否され、利用者は初回に「システム設定 → プライバシーとセキュリティ → このまま開く」が必要です（macOS 15 以降は右クリックの「開く」では回避できません）。サイトのインストール手順はこの前提で書いています。

Apple Developer Program に加入して Developer ID Application 証明書を用意すると、警告なしで開ける公証済み DMG にできます。

### ローカルで署名・公証する

```sh
xcrun notarytool store-credentials choco-notary --apple-id <Apple ID> --team-id <TEAM ID> --password <app 用パスワード>
DEVELOPER_ID_APP="Developer ID Application: <名前> (<TEAM ID>)" NOTARY_PROFILE=choco-notary VERSION=0.1.0 ./scripts/make-dmg.sh
```

### GitHub Actions で署名・公証する

リポジトリの Secrets に次を登録すると、Release ワークフローが自動で署名・公証します。1つでも欠けると、ある範囲までの処理にとどまります（証明書がなければ ad-hoc、公証用の3つが欠ければ署名のみ）。

| Secret | 内容 |
|---|---|
| `MACOS_CERTIFICATE` | Developer ID Application 証明書（.p12）を base64 にしたもの |
| `MACOS_CERTIFICATE_PASSWORD` | .p12 のパスワード |
| `DEVELOPER_ID_APP` | 証明書名。例: `Developer ID Application: 名前 (TEAMID)` |
| `APPLE_ID` | 公証に使う Apple ID |
| `APPLE_TEAM_ID` | チーム ID |
| `APPLE_APP_PASSWORD` | Apple ID の app 用パスワード |

初めて公証する前に、hardened runtime 下でも WebKit と Chrome 拡張機能が動くことを実機で確認してください。公証済みになったら、サイトのインストール手順（`site/index.html`・`site/en/index.html` の `#install`）から「このまま開く」の説明を外します。

## サイトを公開する

1. リポジトリの Settings → Pages で Source を「GitHub Actions」にする
2. `main` に `site/` の変更が入ると `pages.yml` が公開する。公開 URL は通常 `https://tarabakz25.github.io/choco/` になる
3. サイト内のリンクと、ダウンロード先 `github.com/tarabakz25/choco/...` はリポジトリ名 `choco` を前提にしている。リポジトリ名を変えたら `site/` 内の URL を置き換える

ローカルで確認するには次を実行します。

```sh
python3 -m http.server -d site 8000
```

サイト上のアプリ画面はイラストです。実機のスクリーンショットに差し替える場合は、`site/assets/` に画像を置いて `.mock` を置き換えてください。
