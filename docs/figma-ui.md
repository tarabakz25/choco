# Figma UIへの改修

対象: [OSS-Arc / Layouts](https://www.figma.com/design/ZF9ydApZS6Ln3SRZFO2dWk?node-id=14-1052)。既存α版の機能を保ちながら、SwiftUIの画面をデザインへ合わせる。

## 対応した画面

- メイン／サイドバー（20:1138、19:1026）: 12.5rem(200pt)を初期幅とするグレーのサイドバー。戻る・進む・再読み込み・URL入力を左へ集約。Favoritesは3列、タブとフォルダは32ptの行。
- コマンドバー（20:1497、20:1676）: 中央の668×283pt、5行表示とスクロール。ページ側だけ55%暗くし、サイドバーの色は維持。⌘Lは現在のProfileで移動し、他Spaceへの切替は明示選択。
- サイト操作（20:1751）: 220pt幅。クイック操作の4タイルは204pt幅を等分して左右中央に揃え、行・見出しも余分な左右余白を持たない。URL欄右端の20ptタイルは、押下中とポップアップ表示中に選択色（`ChocoTheme.selected`）で点灯する。共有・コピー・固定・Favorites・ページ内検索・Splitを実際のページに接続。Figmaの入場モーションを一度だけ再生し、動きを減らす設定に対応。
- Archive（20:2202）: 96pt rail＋266pt panel。実際のArchiveを検索・Space絞込・日付別表示・復元。右のWebページを表示したまま利用できる。
- 空の状態（157:7042）: お気に入りが0件のときは点線のヒント（ドラッグでタブを追加／×で閉じる）、タブ・フォルダが無いSpaceではSpace名ラベルと選択色なしの「新しいタブ」を表示し、「クリア」は隠す。ヒントの背景は、Space色に依存するFigmaの`#1f2035`ではなく黒の半透明で近似している。
- 新規作成メニュー（149:6932）: 下部の＋を押すと、Spaceの作成シートではなく「新しいSpace／フォルダ／Easel／Boost／Split／タブ」のメニューを開く。＋は45°回転して×になり、メニューは0.28秒のスプリング（0.96倍・下11pt→0）と、行ごとの30ms遅れのフェード・4pt上昇で現れる。外側のクリック・Esc・もう一度＋で閉じる。EaselとBoostは対象外のため無効表示、Splitは現在のタブの隣に空のタブを作ってアドレス入力へ進む（すでにSplit中は無効）。Figmaにある`^⇧E`・`^⇧;`は実装していないキーなので表示せず、実在する`⌘T`だけを表示する。
- ボタンの押下状態: サイドバーのアイコン・行・Spaceボタンは`ChocoPressStyle`で押下中に選択色を重ねる（無効なボタンは対象外、動きを減らす設定ではアニメーションなし）。
- サイドバー非表示／ホバー表示（22:2812、22:3001）: 8pt(`ChocoSpace.sm`)のコンテンツ余白、左端での一時表示、表示ボタンと⌘Sで固定表示へ戻る。
- 設定ポップアップ（105:16398、105:16494、105:16716、105:16865）: 684×650ptの独立ウィンドウ。General / Profiles / Shortcuts / Advancedの4タブ、暗いツールバーと紫の選択色を再現。⌘,とサイドバーの設定メニューから開く。

ユーザー確認により、新しいMedia、Easel、Boost、拡張機能などの開発は含めない。Libraryの対象外項目は無効状態にし、サンプルの個人タブ名・履歴・インストール済み拡張・更新通知を実データとして表示しない。バージョン表示は実際のchoco-browserの値を使用する。

## アニメーション設定

設定の「アニメーション」→「動き」で「システムに従う／アニメーションを有効／動きを減らす」を選べる。初期値はシステムに従う。アプリだけ有効にしても、macOS全体やWebサイトのアクセシビリティ設定は変更しない。

外観とアニメーションはGeneralタブに配置し、既存の保存キーを維持する。Profilesは実際のプロファイル名とSpace数を表示し、追加ボタンは設定ウィンドウ内の作成シートを開く。Shortcutsは実装済みのキー操作を検索できる。未対応の自動更新・終了確認・プレビュー・自動Archive・ダウンロード管理・キー変更・データ削除・Boostsなどは無効表示にする。検索は現在のGoogle、起動時の構成復元は常時有効という実際の状態を表示する。設定画面自体はFigmaに合わせたダーク配色を使い、外観の選択はブラウザ本体へ適用する。

## アニメーション

- タブの実際の追加・削除は180ms。行のフェード・左8ptの移動と一覧のリフロー、ページ側のフェード・6ptの移動を付ける。単なる選択やSpace切替では開閉演出をしない。
- Sidebarとページ領域は同じ350msのスプリング曲線で連動する。初期幅200ptではページの左端が8→199pt、横幅が2078→1887ptへ変わる。Sidebar自体は200msのease-outでフェードする。
- Sidebarは通常表示とホバー表示で同じビューを保持する。一時表示を固定したとき、二重のSidebarを出したり、WebViewを作り直したりしない。
- サイト操作は320msのスプリングと140msのフェード、URL欄の実際の押下は70msの表示・230msの解放フィードバック。
- コマンドバーは140msのフェードと小さな拡大縮小、閉じるときもフェードする。ページ側の暗転も連動する。
- Figmaの51サンプルを共通化し、5.27%のオーバーシュートを残す。デモ用タイムラインの待ち時間や無限ループは、操作待ちや自動開閉には変換しない。コマンドバー・閉じる動作はFigmaに専用トラックがないため、同じイージング系列の短い値を採用した。
- 動きを減らす設定では移動・拡大縮小を行わず、最終状態へ切り替える。素早い反転操作や、ホバー中にメニューを開閉した場合にも操作状態を維持する。

## 構成とアセット

`ChocoTheme`に色・寸法・文字組のトークンを集約し、`DesignIcon`と`SiteIcon`から元のアセットを利用する。Figmaから取得したSVGを未改変で残し、AppKit表示用のPDFに忠実に変換した。小数点サイズのPDFは元のページ寸法を復元してから表示する。

InterとNoto Sans JPをプロセス内だけで登録する。フォント・アイコンはアプリに同梱し、期限付きFigma URLへの実行時アクセスは行わない。ライセンス・出典は[THIRD_PARTY.md](../THIRD_PARTY.md)を参照。

SwiftPMのResource bundleは`Contents/Resources/choco-browser_BrowserApp.bundle`へコピーする。Xcodeアプリは同じResourceファイルをメインbundleへ格納する。WebKit・Profileデータ・保存形式は変更しない。

## 操作と互換性

- サイドバー下部のLibraryボタンからArchiveへ移動する。Archiveの⌘Wは一覧を閉じ、背後のタブを残す。
- URL欄右端のサイト操作からSplitの作成・左右交換・解除へ進む。
- タブ・フォルダの右クリック操作、Space/Profile編集、Archive復元、ショートカットを継続利用できる。
- ブラウザの表示領域は既存のWKWebViewを使用する。サイドバー・Library・Splitの切替で、ページを作り直すレイアウトにはしない。
- macOS標準のウィンドウ操作は本物のOSコントロールを使う。Figmaの非アクティブ状態の丸をボタンの代わりに描かない。

検証結果は[verification.md](verification.md)に記載する。

## 基底UI部品（`DesignSystem/Components`）

Figmaの「Dialog Controls」（184:1422）と「Icons」（5:221）を、画面に依存しない部品としてまとめた。色は`ChocoTheme.Settings`／`ChocoTheme.Dialog`（`ChocoControlTheme.swift`）に、Figmaの変数名どおりに置く。

| 部品 | 引数 | Figma上の寸法・状態 |
| --- | --- | --- |
| `ChocoButton` / `.buttonStyle(.choco(...))` | `kind`（primary・secondary・blue・indigo）、`keyHint`（"ESC"などのキーチップ） | 高さ32・左右16・角8。Default／Hover／Pressed／Disabledは環境から決まる。無効はPrimary・Secondaryが不透明度45%、Blueは専用の淡色 |
| `ChocoTextField` | `tone`（settings・space）、`focus`、`onSubmit` | settingsは高さ36でフォーカス時に2ptの紫枠、spaceは高さ40で枠は変えずキャレットが`dialog/caret` |
| `ChocoColorSwatch` | 色、`isSelected`、`label`（VoiceOver用） | 32ptの領域に24ptの円、選択中は2ptのリング |
| `ChocoSlider` | `value`、`in`、`step` | 高さ20・トラック4・つまみ16。幅は親に従う（Figmaは288） |
| `ChocoIcon` | `DesignIcon(.plus)`の形で使う | Figmaの全44アイコンを意味の名前で引ける |

FigmaではPrimary・Blue・Indigoにホバー／押下専用の色がなく、無効のIndigoも通常と同じ。そのためSecondaryだけが状態で色を変える。デザインに色が追加されたら`ChocoButtonKind.palette(for:)`の1か所を直す。既存の画面（`EditorSheet`・設定の`SettingsButtonStyle`など）はこの部品へ未移行で、移行は画面ごとに外観を確認しながら行う。

## 余白（rem基準）

余白は`DesignSystem/ChocoSpace.swift`のトークンを使う。1rem=16pt。`xxs`2 / `xs`4 / `sm`8 / `md`12 / `lg`16 / `xl`24 / `xxl`32。`rem`を変えると全体の余白が連動する。**Figmaの実測値が優先**で、トークンと値が一致する箇所だけトークンを使い、スケール外の値（5・6・9・10・14・18・26・27など）はFigmaに合わせてリテラルのまま残す。サイドバーは12.5rem(200pt)・内側余白`sm`、コンテンツ余白`sm`、サイト操作は13.75rem(220pt)。
