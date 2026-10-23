# 検証記録

検証日: 2026-10-23。環境: Apple Silicon / macOS 27.0.1 / Xcode 27.1 / Swift 6.4。アプリのdeployment targetはmacOS 15.4。

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
