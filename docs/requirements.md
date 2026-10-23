# 開発要件と機能対応表

## 決定事項

macOS専用、macOS 15.4以上、Swift 6 / SwiftUI / WebKit、MIT。最初の納品はローカル起動できるα版。外観と操作はArcに近づけるが、Arcのサービス・ソース・画像資産には依存しない。

この表の段階は**実装対象の割当**であり、実装済みという意味ではない。実際の検証結果と残課題は[検証記録](verification.md)を参照。後続段階のAI提供元、同期サーバー、課金、共同編集方式などは未決定で、αの実装に持ち込まない。

αは単一メインウィンドウ。Spaceは整理単位、Profileはログイン分離単位。Favoritesは全Space共通の定義とProfile別の閲覧状態を持つ。階層フォルダはPinned内に置く。Splitは同一Spaceの2タブまで。Todayを閉じるとArchiveへ移し、固定登録は通常の終了操作では消さない。

## αの受入条件

|ID|観測可能な完了条件|
|---|---|
|AC-01|URL入力で実際のページを表示し、戻る・進む・再読み込み・ページ内検索を実行できる|
|AC-02|タブの作成・固定・名前変更・複製・移動・基準URLリセットが正しい所属と順序を維持する|
|AC-03|Spaceの作成・切替・外観・Profile割当が反映され、別Profile間でCookieが混ざらない|
|AC-04|Todayの終了・まとめて終了・Archive復元で消失や二重登録がない|
|AC-05|Favoritesは最大12件、リンク定義は共通、ログイン状態はProfile別|
|AC-06|階層フォルダに循環・他Space参照が生じず、削除時に子要素を失わない|
|AC-07|コマンドバーでURL・検索・既存タブ・主要操作を選び、キーボードで完結できる|
|AC-08|2タブのSplit作成・幅変更・交換・解除ができ、片側終了時に単一表示へ戻る|
|AC-09|再起動でURL・独自名・所属・順序・選択・Splitを復元し、非表示タブを一斉に読み込まない|
|AC-10|ポップアップ・ダイアログ・ファイル選択・ダウンロード保存を処理する|
|AC-11|保存失敗・破損・読み込み失敗を表示し、元データを無言で空状態に置換しない|
|AC-12|TLS検証を維持し、非公開APIを使用せず、日本語入力とフォーカスを壊さない|

## 全機能の対応表

元の機能名を残し、同じ目的の機能も追跡可能にする。Archiveと履歴、共有と同期、起動時のSplit復元と再利用可能なSaved Splitは別要件。

### タブ・ウィンドウ管理

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|TAB-01|Vertical Tabs|α|左サイドバーにタブを縦表示|
|TAB-02|Today Tabs|α|一時タブを固定タブから分離|
|TAB-03|Pinned Tabs|α|明示解除まで登録を保持|
|TAB-04|Favorites|α|全Space共通のリンクを最大12件登録、閲覧状態はProfile別|
|TAB-05|Folders|α|固定タブをフォルダへ格納|
|TAB-06|Nested Folders|α|同じSpace内でフォルダを階層化し循環を防止|
|TAB-07|Auto Archive|β|Profile設定に従い未使用Todayを自動整理|
|TAB-08|Archive|α|閉じたTodayを一覧・直前操作から復元|
|TAB-09|Tab Search|α|タイトル・独自名・URLから既存タブを検索|
|TAB-10|Tab Rename|α|ページタイトルとは別の独自名を設定|
|TAB-11|Tab Duplicate|α|同じURLの新規タブを作成|
|TAB-12|Tab Move|α|Space・固定フォルダ間で移動、Profile変更時はセッション再生成|
|TAB-13|Multi-select Tabs|β|複数選択による移動・終了・整理|
|TAB-14|Reset Pinned Tab|α|登録した基準URLへ戻す|
|TAB-15|Edit Pinned URL|α|現在URLと分けて基準URLを編集|
|TAB-16|Clear Today|α|現在SpaceのTodayをまとめてArchive|
|TAB-17|Collapsible Pinned Tabs|α|固定領域とフォルダを折りたたみ|
|TAB-18|Tab Switcher|α|キーボードで最近使ったタブを切替|
|TAB-19|Session Restore|α|所属・順序・URL・選択・Splitを復元|
|TAB-20|Multiple Windows|β|独立ウィンドウで閲覧|
|TAB-21|Incognito Window|β|非永続WebKitデータと非永続アプリ状態を利用|

### ワークスペース・整理

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|SPACE-01|Spaces|α|仕事・個人などのタブ構成を分離|
|SPACE-02|Space Switching|α|サイドバーとキー操作で切替、スワイプは後続|
|SPACE-03|Space Icons|α|Spaceの絵文字アイコンを編集|
|SPACE-04|Space Themes|α|Spaceごとのアクセント色を編集|
|SPACE-05|Profiles|α|安定したUUIDのWebKitデータストアでログインを分離|
|SPACE-06|Profile Assignment|α|SpaceにProfileを割当、変更時にセッション再生成|
|SPACE-07|Profile-specific Settings|β|アーカイブなどの設定をProfile別管理|
|SPACE-08|Shared Spaces|オンライン・制作・配布|第三者にSpaceのリンク集を共有|
|SPACE-09|Shared Folders|オンライン・制作・配布|フォルダのリンク集を共有|
|SPACE-10|Shared Split Views|オンライン・制作・配布|Split構成を共有し受信側で復元|
|SPACE-11|Shared Selected Tabs|オンライン・制作・配布|選択したリンク集を共有|
|SPACE-12|Arc Sync|オンライン・制作・配布|独自の端末間同期、Arcのサービスには接続しない|
|SPACE-13|Air Traffic Control|操作拡充|URL条件でリンクを開くSpaceを選択|
|SPACE-14|Automatic GitHub Live Folders|操作拡充|GitHub PR連携と統合し認可した範囲を収集|
|SPACE-15|Live Calendars|操作拡充|認可した予定の次回会議と参加リンクを表示|

### マルチタスク・画面表示

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|VIEW-01|Split View|α|同じSpaceの2タブを左右に表示、幅変更・交換・解除|
|VIEW-02|Saved Split Views|操作拡充|再利用できるSplitをタブとして保存、単なる起動時配置復元と区別|
|VIEW-03|Drag to Split|操作拡充|ドラッグでSplitを作成|
|VIEW-04|Split Rearrangement|α|左右交換、任意構成のドラッグ並替は後続|
|VIEW-05|Peek|操作拡充|一時的なリンクプレビュー|
|VIEW-06|Peek to Split|操作拡充|プレビューをSplitの一方へ昇格|
|VIEW-07|Little Arc|操作拡充|外部リンクを小さなウィンドウで表示|
|VIEW-08|Mini Video Player|操作拡充|WebKitで対応可能なPiPを提供|
|VIEW-09|Mini Audio Player|操作拡充|再生中音声をサイドバーから操作|
|VIEW-10|Multi-media Controls|操作拡充|複数再生セッションを管理|
|VIEW-11|Site Previews|操作拡充|対応サービスの情報をホバー表示、送信範囲を明示|
|VIEW-12|Hide Sidebar|α|表示と非表示を切替|
|VIEW-13|Full Screen|α|macOS標準の全画面操作を利用|
|VIEW-14|Custom Toolbar|操作拡充|表示項目をカスタマイズ|
|VIEW-15|Dark / Light Appearance|α|システムの明暗に追従|

### 検索・ナビゲーション・操作

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|NAV-01|Command Bar|α|URL・検索・タブ切替・主要操作を統合|
|NAV-02|Command Bar Actions|α|定義済みのブラウザ操作を検索して実行|
|NAV-03|Search Suggestions|β|明示同意した外部候補、αでは取得しない|
|NAV-04|Open Tab Suggestions|α|新規検索前に既存タブを提示|
|NAV-05|Space-aware Suggestions|α|現在Spaceの既存タブを優先|
|NAV-06|Site Search|操作拡充|設定したサイト内検索へ入力を渡す|
|NAV-07|Custom Search Engines|β|検索先を設定、αはDuckDuckGo|
|NAV-08|Custom Keyboard Shortcuts|β|キー割当の編集と競合検知|
|NAV-09|Keyboard Navigation|α|主要操作と候補選択をキーボードで実行|
|NAV-10|Quick Tab Switch|α|直前または最近使ったタブへ切替|
|NAV-11|Super Copy|操作拡充|選択した複数URLを一括コピー|
|NAV-12|Clean Link Copy|操作拡充|追跡パラメータを任意除去してコピー|
|NAV-13|Share Quote|操作拡充|対応ページで引用箇所へのリンクを生成|
|NAV-14|Create App Documents|操作拡充|サービスの文書作成URLをコマンドから開く|
|NAV-15|Find in Page|α|WebKitの検索でページ内を移動|
|NAV-16|Browser History|β|訪問記録の検索・削除、Archiveとは別管理|
|NAV-17|Import Browser Data|β|利用者が選んだ書出ファイルを取込、パスワード移行は別途調査|
|NAV-18|Export Data|β|Space・タブを文書化した形式で書出|

### カスタマイズ・コンテンツ作成

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|CONTENT-01|Boosts|操作拡充|サイト単位の変更設定を管理|
|CONTENT-02|Boost Color Editing|操作拡充|色の変更をサイトへ適用|
|CONTENT-03|Boost Font Editing|操作拡充|フォントと文字サイズを変更|
|CONTENT-04|Zap|操作拡充|指定要素を非表示、適用範囲と解除を提示|
|CONTENT-05|Custom CSS Boost|操作拡充|ユーザー指定CSSを明示したサイトに適用|
|CONTENT-06|Custom JavaScript Boost|操作拡充|既定無効、サイトごとの明示許可と解除を必要とする|
|CONTENT-07|Boost Sharing|オンライン・制作・配布|共有可能な変更のみ公開、JSの安全方針を別途設計|
|CONTENT-08|Easels|オンライン・制作・配布|素材を配置できるキャンバス|
|CONTENT-09|Easel Text & Drawing|オンライン・制作・配布|テキスト・描画の編集|
|CONTENT-10|Easel Media Embeds|オンライン・制作・配布|画像・動画などを配置|
|CONTENT-11|Easel Live Captures|オンライン・制作・配布|部分ページ埋込の可否とサイト分離を調査|
|CONTENT-12|Easel Collaboration|オンライン・制作・配布|共同編集・権限・競合を設計|
|CONTENT-13|Easel Export|オンライン・制作・配布|PNGなどへ書出|
|CONTENT-14|Partial Page Capture|操作拡充|選択領域を画像として保存|
|CONTENT-15|Full Page Capture|操作拡充|ページ全体を取得、長大ページの限界を明示|
|CONTENT-16|Portrait Mode|操作拡充|共有用の装飾付き画像を生成|
|CONTENT-17|Library|操作拡充|保存画像・ダウンロード・Archiveを集約、Easelは追加時に統合|
|CONTENT-18|Recent Files|操作拡充|アプリから保存した最近のファイルを表示|
|CONTENT-19|Default Notes App|操作拡充|外部ノートアプリへの明示的な引渡先を設定|

### AI機能

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|AI-01|5-Second Previews|オンライン・制作・配布|同意したリンクの内容を要約|
|AI-02|Tidy Tab Titles|オンライン・制作・配布|固定タブ名の提案、元の名前を復元可能|
|AI-03|Tidy Downloads|オンライン・制作・配布|ファイル名の提案・変更、対象と送信内容を明示|
|AI-04|Tidy Tabs|オンライン・制作・配布|一時タブのグループ化を提案|
|AI-05|Instant Links|オンライン・制作・配布|検索から直接開く候補を提示・制御|
|AI-06|Instant Links Multi-search|オンライン・制作・配布|複数検索に基づくタブ作成を制御|
|AI-07|ChatGPT in Command Bar|オンライン・制作・配布|明示的な質問先として接続、認証・課金境界は別設計|
|AI-08|Arc Max Feature Toggles|オンライン・制作・配布|機能ごとの個別ON/OFFと送信同意|
|AI-09|Ask on Page|任意候補|削除済み機能の任意復刻候補、必須にはしない|

### 開発者向け

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|DEV-01|Developer Mode|操作拡充|開発用ツールバーと機能を有効化|
|DEV-02|Auto Developer Mode|操作拡充|localhost表示時の切替を設定|
|DEV-03|Developer Tools|β|Chromium DevToolsの代わりにSafari Web Inspectorを利用|
|DEV-04|Inspector|β|Safari Web InspectorでDOMを検査|
|DEV-05|Console|β|Safari Web InspectorでJavaScriptを調査|
|DEV-06|Network Inspector|β|Safari Web Inspectorで通信を調査|
|DEV-07|JSON Formatter|操作拡充|JSONレスポンスを読みやすく表示|
|DEV-08|Full URL Toolbar|α|現在URLを確認できるツールバー、開発専用カスタマイズは後続|
|DEV-09|Developer Screenshot|操作拡充|開発ページをキャプチャ|
|DEV-10|Multiple Test Profiles|α|別Profileで同一サイトのCookie状態を分離|
|DEV-11|GitHub PR Integration|操作拡充|SPACEのGitHub Live Foldersと同一要件へ統合|
|DEV-12|WebGPU Support|操作拡充|WebKitとOSの対応を検出、全対象OSでの対応は保証しない|
|DEV-13|Chrome Extensions|操作拡充|WKWebExtensionによる対応拡張を検証、Chrome Web Store完全互換は対象外|
|DEV-14|AppleScript Integration|操作拡充|ウィンドウ・Space・タブ操作の辞書と権限を設計|
|DEV-15|Extension Management|操作拡充|対応拡張のインストール・権限・無効化・削除|

### 標準機能・セキュリティ

|ID|元の機能名|段階|要件・制約|
|---|---|---|---|
|BASE-01|Chromium Engine|代替確定|WebKitに置換、Chromiumの組込・フォークは行わない|
|BASE-02|Password Manager|β|資格情報の管理方式を調査、平文保存しない|
|BASE-03|Password Autofill|β|関連APIとブラウザ用entitlementの条件を調査|
|BASE-04|Form Autofill|β|住所・決済情報の安全な扱いと公開APIを調査|
|BASE-05|Website Translation|操作拡充|翻訳方式・送信先・同意を別途設計|
|BASE-06|Download Manager|β|αの保存ダイアログを履歴・進捗・中断管理へ拡充|
|BASE-07|Website Permissions|β|αはOS/WebKitの確認を利用、サイト単位の管理画面を後続追加|
|BASE-08|Cookie Management|β|Profile別の確認・削除|
|BASE-09|Cache Clearing|β|Profileと対象データを選んで削除|
|BASE-10|Tracking Protection|β|WebKit標準保護に加えるルール・例外を設計|
|BASE-11|HTTPS Security|α|標準の証明書検証を維持し、エラーを自動承認しない|
|BASE-12|Default Browser|β|利用者がOS設定から選べるよう登録|
|BASE-13|Web Printing|β|印刷とPDF保存|
|BASE-14|Page Zoom|β|サイト・タブの拡大縮小|
|BASE-15|Auto Update|オンライン・制作・配布|配布署名・公証・更新署名・検証を設計|
|BASE-16|Recovery Cards|オンライン・制作・配布|独自の暗号化同期の復旧手段、Arc復旧カードとの互換ではない|
|BASE-17|Encrypted Arc Sync|オンライン・制作・配布|独自同期のE2EE、鍵・紛失・失効・競合を別設計|
|BASE-18|Custom App Icons|操作拡充|利用者が選んだアプリアイコンに変更|

## 後続段階の開始条件

- β: αの受入確認を通過してから移行・日常利用上の不足を優先する。パスワードなどの「調査」項目は利用可能な公開APIと必要な認可を確認するまで対応を約束しない。
- 操作拡充: 中核モデルとProfile分離を壊さず、各機能に解除・復旧と受入条件を設ける。
- オンライン・制作・配布: 共有範囲、鍵管理、削除、同期競合、外部送信、提供元・費用を決定してから実装する。αで暗黙に外部サービスへ接続しない。
