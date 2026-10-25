# choco

SwiftUIとWebKitで作る、Arcの整理・操作体験を目指したmacOS用OSSブラウザです。MITライセンス。Arc / The Browser Companyとは独立したプロジェクトです。

## 開発環境・起動

- macOS 15.4以上
- Xcode 16.3以降（Swift 6）。Command Line Toolsの選択先もXcodeに設定してください。
- 外部Swiftパッケージの依存はありません。

```sh
git clone https://github.com/tarabakz25/choco.git
cd choco
./scripts/build-app.sh
open build/choco.app
```

`Choco.xcodeproj`をXcodeで開き、`Choco` schemeを実行することもできます。スクリプトのビルドはローカル用のアドホック署名です。公開配布用の署名・公証・自動更新は含みません。

```sh
./scripts/test.sh
./scripts/build-app.sh release
```

## α版の範囲

- 実際のWeb閲覧と戻る・進む・再読み込み
- 縦タブ、Today / Pinned、最大12件のFavorites、階層フォルダ
- Spaceのアイコン・色、ProfileごとのCookie・ログイン状態の分離
- URL入力・検索・既存タブ切替・操作コマンドをまとめたコマンドバー
- 同じSpaceの2タブを表示するSplit
- 手動Archiveと復元、起動時の構成復元

α版は単一メインウィンドウです。複数ウィンドウ、プライベート閲覧、自動Archive、Arcからのインポート、AI、同期、Boosts、拡張機能などは後続段階です。全機能の対応表は[開発要件](docs/requirements.md)にあります。

## 主な操作

|キー|操作|
|---|---|
|⌘T|新しいタブ・検索・既存タブ候補|
|⌘L|現在ページのURL入力。別タブ候補へ移るには明示選択|
|⌘W / ⇧⌘T|TodayをArchive / 閉じたタブを復元|
|Control+Tab / Control+Shift+Tab|最近使った順でタブを切替|
|Control+Option+← / →|Spaceを切替|
|⌘F / ⌘R / ⌘S|ページ内検索 / 再読み込み / サイドバー切替|

Space・Profileの作成は左下のメニューから、タブとフォルダの整理は右クリックメニューから行えます。フォルダは親変更と兄弟順の変更に対応します。

## Figma UI

[指定デザイン](https://www.figma.com/design/ZF9ydApZS6Ln3SRZFO2dWk?node-id=14-1052)に合わせ、サイドバー・コマンドバー・サイト操作・Archiveを改修しています。Archiveは左下のLibraryから、SplitはURL欄右端のサイト操作から開きます。[対応範囲と構成](docs/figma-ui.md)に詳細があります。

設定の「アニメーション」から、choco内の動きをシステムに従わせるか、有効にするか、減らすか選択できます。

## データとプライバシー

タブ構成はApplication Support内の`OssArc/state.json`へ保存します。アプリをサンドボックス付きで起動した場合はアプリ専用コンテナ内になります。WebサイトのCookieなどはProfileごとにWebKitの永続データストアへ保存します。別Profileへの移動ではログイン状態をコピーしません。お気に入りのリンク定義は全Space共通、実際の閲覧状態はProfileごとです。

アプリ独自のアカウント登録、同期、AI送信、利用状況収集、外部検索候補の取得はありません。明示したWeb検索はDuckDuckGoに送られます。Webサイトへの通常の通信はWebKitが行います。

起動復元はURL・配置・名前などの復元です。フォームの入力内容、ページのJavaScript状態、完全な戻る履歴の保存は保証しません。任意サイトのパスキー・Safariの保存パスワード・DRMサービス・Chrome拡張との互換性はα版の保証対象ではありません。

## 開発資料

- [機能要件と段階](docs/requirements.md)
- [構成とデータの扱い](docs/architecture.md)
- [並列実装の操作契約](docs/implementation-contract.md)
- [検証記録](docs/verification.md)

## 追加の受入テスト

実際のWebKitプロセスを起動するテストは、隔離したテスト用Profileを使用します。

```sh
OSS_ARC_WEBKIT_TESTS=1 ./scripts/test.sh
./scripts/test-ui.sh
```

UIテストはローカルの`127.0.0.1:8765`にテスト専用ページを起動し、ネイティブアプリを操作します。既にこのポートが使われている場合は停止します。XcodeのテストランナーがmacOSの操作許可を求める場合があります。テスト用アプリ状態は通常の状態とは別の`OssArcUITests/<UUID>`に保存します。

## 名前と互換性

公開名は暫定的に`choco`です。初期α版のデータを引き続き使えるよう、内部のbundle identifier（`org.ossarc.browser`）、保存先（`OssArc`）、テスト用環境変数（`OSS_ARC_WEBKIT_TESTS`）は維持しています。
