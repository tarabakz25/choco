# 構成とデータの扱い

## 責任の分離

|モジュール|責任|依存|
|---|---|---|
|BrowserCore|モデル、整合性を維持する操作、保存・復元|Foundation、Observation|
|BrowserRuntime|WKWebView、データストア、ナビゲーションと各delegate|WebKit、AppKit、Observation|
|BrowserApp|SwiftUI画面、メニューとショートカット、CoreとRuntimeの接続|BrowserCore、BrowserRuntime|

外部Swiftパッケージは使用しない。SwiftPMでライブラリの検証とアプリのビルドを行い、Xcodeプロジェクトも同じソースとローカルパッケージを使用する。

## ソースの配置

```text
Sources/
├── BrowserApp/
│   ├── App/                    # 起動、終了、全体の状態と画面の接続
│   │   └── Diagnostics/        # 任意で有効にするローカル動作記録
│   ├── Features/
│   │   ├── Browser/            # メインウィンドウ、WebViewの配置、サイト操作
│   │   ├── Sidebar/            # 縦タブ、Space、ホバー表示
│   │   ├── Settings/           # 設定ウィンドウと4タブ、設定専用の部品
│   │   ├── CommandPalette/     # URL入力、検索、操作候補
│   │   ├── Archive/            # アーカイブの一覧と復元
│   │   └── Editing/            # 名前・URL・Space・Profileなどの編集シート
│   ├── DesignSystem/
│   │   ├── Icons/              # 同梱アイコンの読み込みと表示
│   │   └── Motion/             # 共通の動き、動きを減らす設定
│   └── Resources/              # フォント、SVG、PDF、出典情報
├── BrowserCore/                # データ、操作ルール、保存・復元
└── BrowserRuntime/             # WebKitのセッションとナビゲーション
```

`BrowserApp`内のフォルダは責任を整理する単位で、Swiftのモジュールは分けていない。SwiftPMのターゲットとXcodeの同期フォルダは、同じ配下のSwiftファイルを再帰的に取り込む。アセットの読み込み契約を保つため、`Resources`の位置とファイル名は維持する。

- `App`はアプリの起動・終了と全体の状態を持ち、各機能を接続する。
- `Features`には、その機能の画面・状態・専用部品・macOSとの接続処理をまとめる。設定画面はコンテナ、各タブ、ツールバー、専用スタイル、ネイティブのタイトルバー接続に分ける。
- `DesignSystem`には複数画面で共有する見た目を置く。画面固有の状態やWebKitの操作は持たせない。設定だけで使う色や行部品は`Features/Settings`に置く。
- 新しい表示を追加するときは、まず既存の機能の責任に含まれるかを判断する。小さな専用部品を共有フォルダへ移したり、フォルダごとに別モジュールを作ったりする必要はない。

## モデルの意味

- ProfileはCookieなどのWebサイトデータの分離単位。安定したUUIDをWKWebsiteDataStoreの識別子として再利用する。複数Spaceから同じProfileを参照できる。
- Spaceは整理単位。Profileを1つ参照し、タブとフォルダを持つ。
- Tabの現在URL、固定時の基準URL、ページタイトル、独自の名前を別々に保存する。
- FolderはPinned用。同じSpace内に所属し、循環参照を禁止する。削除時は子要素を親へ戻す。
- Favoriteは最大12件の共通リンク定義。実際のWebViewはFavoriteとProfileの組で保持し、通常タブとして二重登録しない。
- Archiveは閉じたタブを復元するための情報。閲覧履歴とは異なる。
- Splitは既存タブ2件への参照。タブを複製しない。メンバーが閉じられたり別Spaceへ移った場合は単一表示へ戻す。

## 状態変更とWebKitの接続

画面の操作はBrowserActionとしてBrowserStoreに渡す。WebKitから受け取ったURLとタイトルの更新はページの再読み込みを発生させずにモデルへ反映する。WebViewの生成・保持はWebSessionPoolが担当する。SwiftUIの表示更新は既存のWebViewを取り付けるだけで、初期化を繰り返さない。

起動時はモデルを復元・検証してから、表示中のタブまたはSplitの2タブを生成する。非表示の復元タブに対するネットワークアクセスを一斉に始めない。表示中のタブ、Splitの両ペイン、ピン留め、音声再生中、ダウンロード中、未保存のフォーム入力があるタブはWKWebViewを保持する。それ以外で一定時間操作がないタブ、または同時に生かす数の上限を超えた古いタブはWKWebViewを破棄して休止し、URLとスクロール位置だけを残す。再選択時に同じURLを読み直し、残しているスクロール位置があれば戻す。メモリ圧迫時は保護対象を除き、最後に操作した時刻が古いものから休止する。同じProfileのタブは一つのWKWebsiteDataStoreを共有する。macOS 12以降は追加のWKProcessPoolを作っても効果がないため、プロセスプールは複製しない。Profileを変えた場合は元のWebViewを破棄し、そのProfileのデータストアで作り直す。休止は状態として保持し、サイドバーの見た目は変えない。

ポップアップはWebKitが渡すconfigurationを使用する。独自のHTTPクライアントでログイン済みダウンロードをやり直す実装は採用しない。TLS検証はWebKitの標準動作を使用し、証明書エラーを自動承認しない。

## 保存と互換性

状態ファイルはschemaVersionを持つJSON。変更を直列化して原子的に保存し、起動時に所属・選択・Splitなどの参照を検証する。破損や未知のschemaVersionを検出した場合は通知し、元ファイルを無言で空状態に置き換えない。

URLとレイアウトは復元するが、DOM、入力中フォーム、JavaScriptのメモリ、全ナビゲーション履歴は永続化しない。同期・共有用の形式は未定義で、ローカル保存ファイルをそのまま公開APIとして扱わない。

## WebKitとOSの境界

macOS 15.4以上でSwiftUIのシェルとNSViewRepresentable経由のWKWebViewを使う。macOS 26以上に限られるSwiftUI WebViewには依存しない。

- 永続Profile: [WebKitのProfile API](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/)
- Web拡張: [WebKit 18.4の公開API](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/)。`BrowserRuntime/Extensions`がインストール（フォルダ・ZIP・CRX・Chromeウェブストア）、保存、Profileごとの`WKWebExtensionController`を持つ。`BrowserApp/Features/Extensions`がタブ・ウィンドウの橋渡しとポップアップ・オプションページ・権限確認を担う。全Chrome APIの互換性は保証しない。
- 開発者向け検査: [Safari Web Inspector](https://developer.apple.com/documentation/safari-developer-tools/enabling-inspecting-content-in-your-apps)。非公開APIによるアプリ内Inspector起動は行わない。
- 一般サイトのパスキー: [ブラウザ向けentitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.web-browser.public-key-credential)などの条件を後続段階で評価する。

サンドボックスではネットワーククライアント、利用者が選択したファイル、カメラ・マイク・位置情報の必要な権限のみ宣言する。サイトへの許可とOSからの許可は別であり、自動で全面許可しない。通常のHTTPサイト表示のためATSはWebコンテンツに限って任意通信を許可する。これはTLS証明書検証を無効化する設定ではない。
