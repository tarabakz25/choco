# 検証記録

検証日: 2026-10-23。環境: Apple Silicon / macOS 27.0.1 / Xcode 27.1 / Swift 6.4。アプリのdeployment targetはmacOS 15.4。

## 追補：アニメーション設定とアイテム自身の描画

以前の「曲線のテスト成功」は、起動中の全アニメーションが有効である証明ではなかった。ライブのOS設定はreduceMotion=1であり、当初chocoもそれに従っていた。ユーザーの承認により、choco限定の「有効」設定を追加して適用した。OS全体の設定は1のまま、アプリ内の実効値はfalseと実行時ログで確認した。

また、領域全体は中間幅を描画する一方、当初のタブAnyTransitionは実アプリでもコンポーネント再現でも中間値0だった。ウィンドウ領域の処理とは分け、行・ページの表示snapshotを保持して実際の進行値を変える方式へ修正した。Coreの終了・Archive処理は遅らせない。行は高さ・間隔・透明度・位置、ページは透明度・位置を180msで描画する。

- 実アプリの修正前: Sidebar幅29件、ネイティブページ位置23件の中間値、タブ行/ページは0。
- 修正後の実アプリ: タブ行57件、ページ99件の中間描画値を確認。設定はsystemReducedMotion=true/effectiveReducedMotion=false。
- 独立した実コンポーネント再現でも、新方式は追加・終了ともに中間値あり。古い方式は明示withAnimationを付けても0。
- 表示キャッシュの終了・途中復元・重複防止・Reduce Motion即時反映の回帰テストを追加。
- 標準Spaceの絵文字🌐を公式Material Iconsのlanguageへ差替え、起動中アプリの実画面で確認。独自アイコン、識別子、タブデータは保持。

描画診断は明示引数指定時のみ、内容やURLを含めず、各操作30秒/1プロセス600件までをローカルに記録する。通常起動では無効。Native UIテスト基盤の初期化問題とは分けて検証した。

## Figma UI・アニメーション改修

- 実WebKitを含む43テストが成功（`.build/figma-motion-all-tests.log`）。Core20、Runtime11、App/アセット/モーション8、実WebKit4。スキップなし。
- Figmaの元SVG73点とPDF、Inter/Noto Sans JPの同梱、PDFの小数点寸法、43テストのスプリング参照値を確認。
- `build/choco.app`のReleaseビルドと署名検証が成功（`.build/figma-motion-release.log`）。
- 専用セッションのReleaseアプリで、メイン／中央コマンドバー／サイト操作／Library型Archiveの実画面を確認。⌘T入力、⌘Lの自動フォーカスと全選択、実ページへの移動、Split作成と片側終了、Archive検索・復元、サイドバー非表示、短時間の連続開閉後のページ維持を確認した。
- サイドバーとページ移動は350msの共通スプリング、Site Controlsは320ms、コマンドは140ms、URL押下は70ms/230ms。詳細は[figma-ui.md](figma-ui.md)。曲線はFigmaの51サンプルと一致し、オーバーシュートを残す。閉じる途中の負幅は防止する。
- 新しいネイティブUIテスト6ケースは追加したが、この環境ではアプリ操作前に自動操作モードの初期化がタイムアウトした（`.build/figma-ui.log`）。開発者モードが無効なことも確認したが、OS設定は変更していない。上記の実画面確認と、UIテスト6件の自動成功は区別する。
- 左端ホバーはネイティブのtracking areaで実装・レビュー済み。今回の操作ツールには連続ホバーAPIがなく、ユーザー操作も検知したため、その最終実動作・動画フレーム検証は未確認。Reduce Motionもコード分岐の確認であり、ユーザーのOS設定を変更した試験は行っていない。
- 操作中の検証用ウィンドウと、そのセッションデータは残している。通常の閲覧データの移行・上書きは行っていない。UI改修はローカルのみで、GitHubへの追加pushは行っていない。

## chocoへの名称変更後

公開名・実行ファイル・Xcodeプロジェクト・schemeをchoco/Chocoへ変更。既存データとProfileを維持するためbundle identifierと保存先は変更していない。

- 実WebKitを含む38テストが成功（`.build/choco-tests.log`）。
- `build/choco.app`のReleaseビルドと署名検証が成功（`.build/choco-release.log`）。
- ネイティブUIの4ケースが成功。基本2ケースは`.build/choco-ui.log`、中断で接続が失われたProfile/Splitの2ケースは新しいランナーで再実行して成功（`.build/choco-ui-resumed.log`）。

## 初期α版の実装結果

α版実装完了時点でCore・Runtime・Appモデル・実WebKitの38テストと、ネイティブUIの4テストがすべて成功。Releaseアプリを再生成した。

- 非UI: `.build/final-tests.log`（`OSS_ARC_WEBKIT_TESTS=1 ./scripts/test.sh`）
- UI: `.build/final-ui.log` / `.build/final-ui.xcresult`（`./scripts/test-ui.sh`）
- Release: `.build/release-final.log`（改名前のアプリ。現在の出力先は`build/choco.app`）

これらの生成物はGitの対象外。

## 実行済み

|検証|結果・確認範囲|
|---|---|
|BrowserCore|20テスト成功。操作、参照修復、固定URL、Archive、Split、保存・復元・エラー・古いrevision拒否|
|BrowserRuntime|11テスト成功。URL入力のパラメータケースと、Poolの同一性・Profile変更・Popup照合・zero UUID保護|
|BrowserAppモデル|3テスト成功。Split右ペインの選択復元、非表示タブへの誤操作防止、MRU、古いFavoriteからのProfile越境Popup拒否|
|実WebKit|4テスト成功。HTML/JS実行、Profile間Cookie分離・同じProfileの再取得、保存SplitとPool同一性、srcdoc/data子フレーム|
|基本ネイティブUI|Cmd+L/T/W/Shift+T、Archive、アプリ再起動、ページ入力、target=_blankの2ケース成功|
|ProfileのネイティブUI|Profile/Space作成、Cookie分離、元のProfileへの復帰、アプリ再起動後の永続Cookie保持に成功|
|SplitのネイティブUI|右ペインへの移動・入力、配置・選択の再起動復元、片側終了後の単一表示を回帰確認|
|Releaseアプリ|ローカル用アドホック署名の.app生成成功。署名検証とシステム依存のみであることを確認|

実WebKitを含む38テストの実行:

```sh
OSS_ARC_WEBKIT_TESTS=1 ./scripts/test.sh
```

通常の`./scripts/test.sh`ではWebKitプロセスを必要とするテストはスキップされる。UIテストは別で実行する。

```sh
./scripts/test-ui.sh
```

## 反証で発見・修正した問題

- 保存データのProfile参照が欠けた場合に、先頭の別Profileを割り当ててしまう。元のUUIDのProfileを復旧し、Space自体が欠けた場合は新しい隔離Profileへ復旧する。
- Profile変更前のFavoriteがPopupを開くと、古いCookieを別Profileのタブへ持ち込める。起点Profile、現Space、WebKitから受け取ったconfigurationを照合し、登録前に拒否する。
- Split右側の選択が保存されず、アドレス操作が左側を対象にする。表示中の対象を限定し、選択をモデルへ保存する。
- Splitの片側終了で、モデルは正しいのに残ったWebViewが表示から外れる。単一/SplitでUUID付きの同じ表示ホストを使用する。
- タブ切替が最近使った順ではない。Controlを押している間の順序を固定し、解放時に最終選択を記録する。
- 通常のsrcdoc/data子フレームを危険なトップレベルURLと同じように拒否する。子フレームだけ許可し、トップレベル制限は維持する。
- Cmd+Lで入力したURLに一致する別Spaceのタブへ暗黙に切り替わる。Cmd+Lの初期選択を現在ページへのナビゲーションに固定し、候補切替は明示操作にする。

別担当によるコードレビューで、上記の修正後に残るBlocking/Should-fixは確認されなかった。レビュー結果とネイティブ動作確認は別の証拠として扱う。

## 限界・未検証

- macOS 15.4実機、Intel Mac、他のmacOSバージョンでの実行は未確認。
- 日本語文字列のJS入出力は確認したが、実IMEによる変換中・未確定文字の手動受入確認は未実施。
- CookieのWebKit単体テストは同一プロセス内での再取得。別のネイティブUIテストでは、Max-Age付きCookieのアプリ終了・再起動後の保持も確認した。すべてのサイトの認証継続を保証するものではない。
- `restorationLoadsOnlyVisibleSessions`は保存メタデータと手動生成したPoolの確認であり、それ単独でSwiftUI画面の全タブ遅延生成を証明しない。
- カメラ・マイク・位置情報、印刷、実サービスのOAuth・パスキー・DRM、Safari保存パスワード、実際のダウンロード保存ダイアログの受入操作は未確認。
- 公開配布用の署名・公証・自動更新は行っていない。
- β以降の機能は対応表へ整理した段階で、αに含めていない。

UIテストはテスト用状態とローカルページのみを使用する。画面資料にはアプリのWindow単位のキャプチャを使用し、利用者のデスクトップ全体は配布資料に含めない。

## 設定ポップアップ（2026-10-25）

- `./scripts/build-app.sh`: 成功。`build/choco.app`へ設定UIと同梱ベクターを格納。
- `./scripts/test.sh --filter BrowserAppTests`: 13件成功、実WebKitを必要とする既存の1件はスキップ。
- `SettingsUITests`: 独立したテスト用状態で2件成功。4タブ、684×650ptのウィンドウ全体寸法、ショートカットの検索・該当なし・解除、プロファイルの作成と通常終了後の復元、⌘Wで設定だけを閉じて元のタブを残す動作を確認。
- Figmaの4画面とネイティブキャプチャを比較し、タイトル位置・上部余白・アイコンの色と寸法を調整。34組のSVG/PDFは非空で、PDFのページ寸法がSVGの元寸法と一致することを確認。
- 外観・アニメーションの保存値は変更していない。未対応項目は無効状態として残し、サンプルの検索エンジンやショートカットを実際の設定と混同しない表示にした。

## UIソースの整理（2026-10-25）

- `BrowserApp`を`App`・`Features`・`DesignSystem`・`Resources`へ整理。設定画面はコンテナ、4タブ、専用部品など10ファイルに分割。配置と責任は[architecture.md](architecture.md)に記載。
- `./scripts/test.sh`: 39件成功、WebKitを必要とする10件は通常実行のためスキップ。
- `./scripts/build-app.sh`: 成功。整理後のソースから`build/choco.app`を再作成。
- Xcodeの`SettingsUITests`2件成功。設定の4タブ・検索・プロファイル作成と再起動後の保持・⌘Wで設定だけを閉じる動作を確認し、4画面のネイティブキャプチャを確認。
- SwiftPMのターゲット、Xcodeの同期ルート、Resourceの位置、保存キー、Core/Runtimeの実装は維持。
