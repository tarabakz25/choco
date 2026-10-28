# リリースと配布

choco-browser は GitHub Releases で DMG を配布し、`site/` の紹介サイトを GitHub Pages で公開します。サイトは Astro + Tailwind CSS で作り、画面デモの映像は Remotion のコンポジションを `@remotion/player` で再生しています。

## 構成

| 何を | どこで |
|---|---|
| DMG 作成 | `scripts/make-dmg.sh`（`task dmg`） |
| リリース公開 | `.github/workflows/release.yml`（`v*` タグの push で起動） |
| 紹介サイト | `site/`（Astro）。日本語 `/`、英語 `/en/`。`.github/workflows/pages.yml` がビルドして公開 |
| ターミナル用インストーラー | `site/public/install.sh`（サイトの `/install.sh` として公開） |
| 仮アイコン | `scripts/make-icon.sh`（`AppSupport/AppIcon.icns` と `site/public/icon.png` を生成） |

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
4. サイトの「ダウンロード」ボタンは `releases/latest/download/choco-browser.dmg` を指す。GitHub がリリース資産へ直接リダイレクトし、`Content-Disposition: attachment` で返すので、クリックするとページ遷移せずその場で DMG のダウンロードが始まる。Release を公開すると最新版に切り替わる
5. サイトの `/install.sh`（`curl -fsSL https://tarabakz25.github.io/choco/install.sh | bash`）も同じ固定名の DMG と `choco-browser.dmg.sha256` を使い、チェックサムを検証して `/Applications` へコピーする。リリースに固定名の2ファイルが無いと失敗する

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

初めて公証する前に、hardened runtime 下でも WebKit と Chrome 拡張機能が動くことを実機で確認してください。公証済みになったら、サイトのインストール手順（`site/src/i18n/ja.ts`・`en.ts` の `install`、`Install.astro`）から「このまま開く」の説明を外します。

## サイトを公開する

1. リポジトリの Settings → Pages で Source を「GitHub Actions」にする
2. `main` に `site/` の変更が入ると `pages.yml` が Bun で依存を入れて型チェック・ビルドし、`site/dist` を公開する。公開 URL は通常 `https://tarabakz25.github.io/choco/` になる
3. サイト内のリンクと、ダウンロード先 `github.com/tarabakz25/choco/...` はリポジトリ名 `choco` を前提にしている。リポジトリ名やアカウントを変えたら `site/astro.config.mjs`（`site` と `base`）、`site/src/config.ts`、`site/public/install.sh` を更新する（`grep -rn "tarabakz25\|/choco" site/src site/public site/astro.config.mjs` で漏れを確認）

### サイトの構成

```text
site/
├─ astro.config.mjs        site / base（/choco）
├─ src/
│  ├─ config.ts            リポジトリ・DMG・インストールコマンドの URL
│  ├─ i18n/{ja,en}.ts      本文とデモ映像の文言（日本語が正、英語は同じ型）
│  ├─ components/          Landing / Header / Features / Install / DownloadButton / RemotionPlayer
│  ├─ scripts/page.ts      スクロール表示・ダウンロード表示・最新版の取得・コピー
│  └─ styles/global.css    Tailwind とブランド色（アプリの ChocoTheme と同じ値）
├─ remotion/               デモ映像（Remotion のコンポジション）
│  ├─ HeroShowcase.tsx     ヒーローの 13 秒ループ
│  ├─ Loops.tsx            機能カードの 5 秒ループ 6 本
│  └─ OgImage.tsx          SNS 共有画像（public/og.png）
└─ public/                 icon.png / og.png / fonts / install.sh
```

ローカルでの作業（`task` でも同じことができる）:

```sh
cd site
bun install
bun run dev        # http://localhost:4321/choco/ （task site:dev）
bun run build      # site/dist を作る（task site:build）
bun run remotion   # Remotion Studio で映像を編集（task site:remotion）
bun run og         # public/og.png を再生成（task site:og）
```

- 映像は Studio で編集したコンポーネントがそのままサイトで再生される（動画ファイルは作らない）。サイトでは画面外で停止し、「視覚効果を減らす」設定では代表フレームで止める。
- 映像に出る画面はイラストで、実機のスクリーンショットではない。実在する機能だけを描き、未対応の機能（複数ウィンドウ、AI、同期など）は描かない。
- 型チェックは `bunx tsc --noEmit`。`astro check` は TypeScript 7 に未対応のため使わない。
- Remotion は利用者の規模によって有償ライセンスが必要になる場合がある。組織で運用する前に Remotion の公式ライセンス条件を確認する。
