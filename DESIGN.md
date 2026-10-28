# DESIGN.md — Choco Browser (Corne / SwiftUI + WebKit macOS)

> このファイルは Figma「Choco-browser」(file key `ZF9ydApZS6Ln3SRZFO2dWk`) から **実測した値のみ**を元に作成しています。
> 取得できなかった項目は **「未確認」** と明記し、推測値は書いていません。
> 取得日: 2026-10-27 (JST)。Figma 側が更新された場合は本書も更新してください。

---

## 1. 概要

- 対象: Arc ライクなブラウザ **Choco**(リポジトリ `tarabakz25/choco`、SwiftUI + WebKit の macOS アプリ)。
- Figma の単位は **px = pt(1x)** として扱います。基準ウィンドウは **2094 × 1127**。
- **rem 変換: 1rem = 16px**。スペーシングは変数コレクション `Spacing (rem)` が正で、rem と px を併記します。
- 変数コレクションは **2 つだけ**です。
  - `Arc Tokens` — 116 変数。`dialog/*`, `little/*`, `search/*`, `settings/*`, `menu/*` などは **別コレクションではなく、`Arc Tokens` 内の名前プレフィックス**です。
    - モード: `Dark` / `Space – Indigo` / `Space – Teal`(Light/Dark ではありません)。
  - `Spacing (rem)` — 18 変数(`space/*`)。
- スタイル: テキストスタイル **30**、エフェクトスタイル **0**、ペイント/グリッドスタイル **0**。影・ブラーはノードに直接設定されています(§6)。
- コンポーネント: Components ページ 69、Layouts ページ(Layout Components 等)9 の top-level コンポーネント / セット。アイコン `Icon/*` は 16×16 基準で約 40 種。
- テーマ: 基本は **ダーク UI**。Web コンテンツ領域(`content/*`)と検索系(`search/*`)のみ明るい配色です。

### 取得できなかった・未確認の主な項目
- **Choco Search 画面**: `search/*` 変数 9 個は存在しますが、Search 用のフレーム/コンポーネントは Figma ファイル内に **見つかりませんでした**(Layouts / Components 両ページを名前検索)。寸法・タイポは **未確認**。
- 各ノードのスペーシングが **変数にバインドされているか**(値は `space/*` と一致していても、バインド有無)は **未確認**。
- Space Card のグラデーション(Gradient テーマ)はリテラル色(§8)。変数化されていません。
- `settings/accent-text` `settings/status-green` `dialog/caret` などの個別の使用箇所は **未確認**(表に明記)。
- 実際の SF Pro 描画での行高・字詰めは **未確認**(Figma は Inter 代替)。

---

## 2. フォント

| 用途 | Figma | 実装 |
|---|---|---|
| 欧文・数字・UI 全般 | **Inter** | **SF Pro(システムフォント)** を使う |
| 日本語 | **Noto Sans JP**(主にタブタイトルなど。未スタイルのテキストで使用) | システムフォント(ヒラギノ等へ自動フォールバック) |

- **SF Pro は Figma 上で描画できないため、Inter を代替として使用しています。** 実装では `Font.system(size:weight:)` を使い、Inter や Noto Sans JP を同梱しないでください。
- Inter は SF Pro より字幅がやや広いため、Figma のテキスト幅・折返しは **目安**です。幅固定にせず、レイアウトは余白とアラインメントで構成してください。
- 全テキストスタイルの **letter-spacing = 0%**、**text case = ORIGINAL**、下線・取消線なし。

---

## 3. タイポグラフィ表(30 スタイル、すべて Inter / px = pt)

| スタイル名 | weight | size | line height | 主な用途 | SwiftUI |
|---|---|---|---|---|---|
| `Sidebar/Tab Title` | Medium | 13 | 17 | タブ・フォルダ名 | `.system(size: 13, weight: .medium)` |
| `Sidebar/Caption` | Medium | 11 | 14 | Divider の Clear | `.system(size: 11, weight: .medium)` |
| `Sidebar/Field` | Regular | 13 | 17 | URL Field | `.system(size: 13)` |
| `Sidebar/Create Title` | Bold | 14 | 18 | Create a Space パネル見出し | `.system(size: 14, weight: .bold)` |
| `Command/Input` | Medium | 17 | 22 | Command Bar 入力 | `.system(size: 17, weight: .medium)` |
| `Command/Row` | SemiBold | 13 | 17 | 結果行・New Menu 項目 | `.system(size: 13, weight: .semibold)` |
| `Command/Action` | SemiBold | 12 | 16 | 行アクション / Space Card Row の Folder 名 | `.system(size: 12, weight: .semibold)` |
| `Library/Title` | Medium | 13 | 17 | Archive/Download Row タイトル | `.system(size: 13, weight: .medium)` |
| `Library/Subtitle` | Regular | 11 | 14 | URL・補足 | `.system(size: 11)` |
| `Library/Section` | SemiBold | 11 | 14 | セクション見出し / Space 名 | `.system(size: 11, weight: .semibold)` |
| `Library/Nav Label` | SemiBold | 10 | 13 | Library Nav ラベル | `.system(size: 10, weight: .semibold)` |
| `Popover/Section` | Bold | 13 | 17 | Popover セクション見出し | `.system(size: 13, weight: .bold)` |
| `Popover/Row Title` | SemiBold | 13 | 17 | Popover 行タイトル | `.system(size: 13, weight: .semibold)` |
| `Popover/Row Subtitle` | Regular | 11 | 14 | Popover 行サブタイトル | `.system(size: 11)` |
| `Pill/Label` | SemiBold | 11 | 14 | Update Pill / Profile Pill / Learn more | `.system(size: 11, weight: .semibold)` |
| `Settings/Body` | Regular | 13 | 17 | Settings 本文 | `.system(size: 13)` |
| `Settings/Body Medium` | Medium | 13 | 17 | ボタン・強調 | `.system(size: 13, weight: .medium)` |
| `Settings/Caption` | Regular | 11 | 14 | 補足 | `.system(size: 11)` |
| `Settings/Tab` | Medium | 11 | 14 | Settings Tab ラベル | `.system(size: 11, weight: .medium)` |
| `Settings/Title` | Bold | 13 | 17 | Settings Window タイトル | `.system(size: 13, weight: .bold)` |
| `Settings/Section` | SemiBold | 11 | 14 | ラベル(Color 等) | `.system(size: 11, weight: .semibold)` |
| `Settings/Keycap` | Medium | 12 | 16 | Keycap Field | `.system(size: 12, weight: .medium)` |
| `Favorites/Empty Title` | SemiBold | 10.5 | 自動 (auto) | お気に入り空状態タイトル | `.system(size: 10.5, weight: .semibold)` |
| `Favorites/Empty Sub` | Regular | 10 | 13 | 空状態サブ | `.system(size: 10)` |
| `Dialog/Title` | SemiBold | 17 | 22 | Create a Space ダイアログ / Little Arc 見出し | `.system(size: 17, weight: .semibold)` |
| `Dialog/Heading` | Bold | 15 | 20 | Profile Dialog 見出し | `.system(size: 15, weight: .bold)` |
| `Dialog/Body` | Regular | 11.5 | 16 | Dialog 本文 | `.system(size: 11.5)` |
| `Dialog/Body Medium` | Medium | 12 | 16 | Space Card Row タイトル / Little Arc ドメイン | `.system(size: 12, weight: .medium)` |
| `Dialog/Note` | Regular | 10 | 13 | 注記 / Space Card Row サブタイトル | `.system(size: 10)` |
| `Dialog/Key` | Bold | 9 | 12 | Key Chip (ESC 等) | `.system(size: 9, weight: .bold)` |

**スタイル未適用のテキスト**(Figma 上で直接指定)
- Tab Row ラベル: 13 / Medium(日本語は Noto Sans JP Medium)。`Sidebar/Tab Title` と同寸なので実装では同じスタイルで可。
- New Menu のショートカット表記(`⌘O` など): 12 / Medium。色 `text/tertiary`。
- Recent File Row のタイトル・時刻: 12 / Regular。
- Library Empty State の見出し: 13 / SemiBold。
- Account Member Card(Kz 26 Bold、肩書 9.5 Medium、ほか 8): 装飾イラスト用。
- 36 / 30 / 28 / 20 の大きな Bold/SemiBold: イラスト・デモ用で UI スタイル外。
- 0.96 倍で縮小配置されたインスタンス内のテキストは 10.56 / 11.52 / 12.48 / 16.32 になりますが、**ソースのスタイル値は上表の通り**です(§12)。

> **行高の実装メモ**: 行高(line height)は Figma の px 値です。SwiftUI では `Text` に `.lineSpacing(行高 − フォント自然行高)` で近似します。1 行テキストは `.frame(height: 行高)` で固定すると Figma に揃います。SF Pro での自然行高は **未確認**。

---

## 4. スペーシング(rem 併記)

1rem = 16px。変数コレクション `Spacing (rem)` の **全 18 変数**:

| 変数名 | rem | px | 主な使われ方 |
|---|---|---|---|
| `space/0` | 0rem | 0px | 区切りなし |
| `space/0_0625` | 0.0625rem | 1px | ヘアライン(1px 線) |
| `space/0_125` | 0.125rem | 2px | 微小ギャップ(Dialog Text Field の gap など) |
| `space/0_25` | 0.25rem | 4px | Tab 行間・小ギャップ |
| `space/0_375` | 0.375rem | 6px | Sidebar のアイテム間 gap・Pill の gap |
| `space/0_5` | 0.5rem | 8px | サイドバー外周 padding(`space/sidebar-pad` は `space/0_5` のエイリアス)・標準 gap |
| `space/0_625` | 0.625rem | 10px | Tab Row 左右 padding・Sidebar 行の gap |
| `space/0_75` | 0.75rem | 12px | Profile Dialog の gap・Dialog Text Field 左右 padding |
| `space/0_875` | 0.875rem | 14px | Command Bar 入力行 padding |
| `space/1` | 1rem | 16px | Dialog/Settings の標準 padding |
| `space/1_125` | 1.125rem | 18px | Command Bar 入力行の左 padding |
| `space/1_25` | 1.25rem | 20px | Space Card Row のインデント |
| `space/1_5` | 1.5rem | 24px | Dialog 下 padding |
| `space/2` | 2rem | 32px | Dialog 上下左右 padding |
| `space/2_5` | 2.5rem | 40px | 用途は未確認 |
| `space/3` | 3rem | 48px | Placeholder Page 上 padding |
| `space/3_75` | 3.75rem | 60px | 用途は未確認 |
| `space/5` | 5rem | 80px | 用途は未確認 |

- `space/sidebar-pad` は `Arc Tokens` 側のエイリアス(= `space/0_5` = 8px)。
- 値は Figma の auto-layout padding / gap と一致しています。各ノードが変数にバインド済みかは **未確認**。

### 実測された代表的な余白
| 場所 | 値 |
|---|---|
| Sidebar 外周 padding | 上 2 / 左右 8 / 下 12、アイテム間 gap 6 |
| Sidebar 行(Tab / Folder / New Tab) | 高さ 32、gap 6〜8、左 padding 10(Tab は右 6) |
| Tab 間 gap | 4 |
| Favorites タイル間 gap | 8 |
| Command Bar 入力行 | 高さ 52、padding 0 / 14 / 0 / 18、gap 10 |
| Command Bar 結果リスト | padding 6 / 6 / 8 / 6、行間 gap 1、行 padding 0 / 6 / 0 / 10 |
| Menu / Popover | padding 8(Popover)・6(New Menu / Easel Toolbar / Little Arc Open Menu) |
| Settings Group / Row | Group 左右 10、Row 上下 8 |
| Dialog(Profile) | padding 32 / 32 / 24 / 32、gap 12 |
| Dialog(Create a Space / Settings 調) | padding 24、gap 20 |
| Boost Editor | padding 16、gap 16 |

---

## 5. 角丸

**変数 (`Arc Tokens`, FLOAT)**: `radius/row` 8 / `radius/tile` 8 / `radius/field` 8 / `radius/cmd` 10 / `radius/popover` 12。

**実際に使われている値(px)と主な用途**

| radius | 用途 |
|---|---|
| 2 | Slider Fill/Track 端、Date Pill |
| 3 | Keycap イラスト、選択ハイライト |
| 4 | Key Chip、Member Card、Cmd 行の矢印ボタン |
| 5 | Tab Close ボタン、Archive 行アクション、Keycap Field、Accent Pill Button |
| 6 | Toolbar Icon Button、Sidebar Bottom Button、Settings ボタン類、Content Area、Little Arc Open Button、Settings Profile Item |
| 7 | Popover Icon/Extension Tile、Popover Footer の pill |
| 8 | Sidebar 行・Favorite Tile・URL Field・Command Bar 結果行・Library 各行・Dialog Button・Text Field・Color Swatch 内部 |
| 9 | Settings Toggle ノブ(18px の円) |
| 10 | Command Bar (`radius/cmd`)、Window / Settings Window / Create a Space / Boost Editor / Favorites Empty State |
| 11 | Update Pill(高さ 22 の半円)、Add Space Button(22px 円) |
| 12 | Site Controls Popover / New Menu / Easel Toolbar / Profile Dialog / Easel Card / Little Arc Window(= `radius/popover`) |
| 14 | Space Card |
| 16 | Color Swatch(32px 円) |
| 26 | Little Arc Hero Tile |
| 104 / 104 / 0 / 0 | Account Member Card のアーチ |
| 完全な円 | 半径 = 辺の半分(Window Controls 12px、Settings Toggle 20px など) |

- 個別角(上のみ丸め等): `8/8/0/0`(Settings Search Field)、`2/0/0/2` と `0/2/2/0`(Slider)、`3/0/0/0` `0/0/0/2`(装飾)。
- 0.96 倍のインスタンスでは 7.68 / 9.6 / 11.52 / 6.72 / 13.44 / 3.84 が出ますが、元の値 8 / 10 / 12 / 7 / 14 / 4 に **揃えて実装**してください(§12)。

---

## 6. 影・ブラー

エフェクトスタイルは **0 件**。以下は **ノードに直接設定された値**です。Figma の `blur(radius)` と SwiftUI の `.shadow(radius:)` は定義が異なり、おおよそ **SwiftUI radius ≈ Figma blur ÷ 2** です(目安)。

| 用途 | 種別 | offset (x, y) | blur | spread | 色 / alpha | 使用箇所 |
|---|---|---|---|---|---|---|
| ウィンドウ | Drop | 0, 18 | 48 | – | #000 / 45% | メインウィンドウ(2094×1127 フレーム) |
| Command Bar | Drop | 0, 16 | 48 | – | #000 / 45% | Command Bar |
| Site Controls Popover | Drop | 0, 10 | 30 | – | #000 / 35% | Popover |
| Site Controls Popover | Background blur | – | 30 | – | – | popover/bg(95% 不透明)の下に敷く |
| New Menu / Easel Toolbar / Little Arc Open Menu | Drop | 0, 8 | 24 | – | #000 / 45% | メニュー類 |
| Sidebar Peek(overlay) | Drop | 0, 10 | 32 | – | #000 / 45% | Sidebar を hover で重ねる状態 |
| Settings Window / Create a Space / Boost Editor | Drop ×2 | 0, 22 / 0, 0 | 60 / 1 | 0 / 0.5 | #000 / 50% / 35% | 2 段重ね(輪郭 + 大きな影) |
| Profile Dialog | Drop ×2 | 0, 16 / 0, 2 | 40 / 6 | 0 | #000 / 50% / 35% | |
| Little Arc Window | Drop ×2 | 0, 24 / 0, 0 | 64 / 1 | 0 / 0.5 | #000 / 45% / 35% | |
| Little Arc Hero Tile | Drop | 0, 6 | 12 | – | #000 / 30% | |
| Settings Toggle ノブ | Drop | 0, 1 | 2 | – | #000 / 25% | |
| Slider Thumb | Drop | 0, 1 | 3 | – | #000 / 40% | |
| Color Wheel ノブ | Drop | 0, 1 | 4 | – | #000 / 45% | |
| Content Area – Easel Card | Drop | 0, 4 | 12 | – | #000 / 12% | Web 面内の装飾 |
| Easel Sticky Note | Drop | 0, 4 | 10 | – | #000 / 18% | 同上 |
| Easel Title / Zoom Chip | Drop | 0, 1 | 6 | – | #000 / 12% | 同上 |
| Keycap イラスト | Inner | 0, −4 | 0 | – | 暗めのマゼンタ / 35% | Settings の装飾 |

- 枠線(stroke): ウィンドウ 1px `#ffffff` 8%(inside)、Popover 1px `#ffffff` 18%、Settings 系ウィンドウ 1px `#ffffff` 12%、Command Bar 1px `cmd/border`(inside)。
- 「Sidebar Peek」を除く Layouts の各フレームは、同じウィンドウシャドウを重複して持っています(複製のため)。

---

## 7. カラートークン

- すべて `Arc Tokens` 変数。**8 桁 hex は `#RRGGBBAA`**(AA = アルファ)。
- 「同左」 = 3 モード同値。値はノードで別 alpha に再指定されている場合があり、その場合は用途欄に記載。
- SwiftUI: 命名規則は `sidebar/bg` → `ArcColor.sidebarBg` のように **lowerCamelCase**。`Theme 依存` と書かれたトークンは、**アクティブな Space のテーマ**から取る(§13)。

### sidebar/*  サイドバー・ウィンドウ背景

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `sidebar/bg` | `#5e5c5c` | `#262538` | `#213a3a` | ウィンドウ全体の背景(Space テーマで変化) | Theme 依存。Space ごとに差し替え |
| `sidebar/field` | `#ffffff12` | `#ffffff17` | `#ffffff17` | URL Field / Update Pill / Library 検索 / フォーム行 | Theme 依存(白 7%/9%) |
| `sidebar/hover` | `#ffffff0d` | 同左 | 同左 | 行・ボタンの hover (白 5%) | 固定 |
| `sidebar/selected` | `#ffffff1f` | 同左 | 同左 | 選択中タブ・Pressed (白 12%) | 固定 |
| `sidebar/tile` | `#ffffff0f` | 同左 | 同左 | Favorite Tile 背景 (白 6%) | 固定 |
| `sidebar/divider` | `#ffffff26` | 同左 | 同左 | Sidebar Divider の線(インスタンスでは 15% に再指定されている) | 固定 |

### text/*  テキスト

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `text/primary` | `#ededed` | 同左 | 同左 | 主要テキスト | 固定 |
| `text/secondary` | `#b9b8b8` | 同左 | 同左 | 副次テキスト | 固定 |
| `text/tertiary` | `#8f8e8e` | 同左 | 同左 | プレースホルダ・ショートカット表記 | 固定 |
| `text/on-light` | `#1e1e1f` | 同左 | 同左 | content/* (明るい面) 上のテキスト | 固定 |

### cmd/*  Command Bar

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `cmd/bg` | `#1e1e1f` | 同左 | 同左 | Command Bar 背景 | 固定 |
| `cmd/selected` | `#565655` | 同左 | 同左 | 選択行 / Add Space Button Hover | 固定 |
| `cmd/separator` | `#353535` | 同左 | 同左 | 入力行と結果の区切り(1px) | 固定 |
| `cmd/border` | `#4f4d4c` | 同左 | 同左 | 外枠 1px (inside) | 固定 |
| `cmd/text` | `#f2f2f2` | 同左 | 同左 | 結果行ラベル | 固定 |
| `cmd/placeholder` | `#8c8c8c` | 同左 | 同左 | 入力プレースホルダ | 固定 |
| `cmd/action-dim` | `#6e6e6e` | 同左 | 同左 | 行右端のアクションラベル | 固定 |
| `cmd/arrow-bg` | `#2e2e2f` | 同左 | 同左 | 行右端の矢印ボタン背景(行 Hover も同色) | 固定 |
| `cmd/arrow-bg-selected` | `#ffffff` | 同左 | 同左 | 選択行の矢印ボタン背景 | 固定 |

### popover/*  Site Controls Popover

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `popover/bg` | `#767676f2` | 同左 | 同左 | Popover 背景 (95%) + 背景ブラー | 固定 + .ultraThinMaterial 等で近似 |
| `popover/tile` | `#232323` | 同左 | 同左 | Popover Icon Button 背景 / Add Space Button Pressed | 固定 |
| `popover/field` | `#ffffff1a` | 同左 | 同左 | Extension Tile 背景 / Icon Button Active | 固定 |
| `popover/icon-circle` | `#ffffff33` | 同左 | 同左 | Settings Row のアイコン円 (28px) | 固定 |

### window/*  ウィンドウ操作

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `window/traffic-inactive` | `#868888` | 同左 | 同左 | 非アクティブ時の信号ボタン | NSWindow 標準に任せる |
| `window/close` | `#ff5f57` | 同左 | 同左 | Close | NSWindow 標準 |
| `window/minimize` | `#febc2e` | 同左 | 同左 | Minimize | NSWindow 標準 |
| `window/zoom` | `#28c840` | 同左 | 同左 | Zoom | NSWindow 標準 |

### media/ library/  Media・Library

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `media/bg` | `#1e1e1e` | 同左 | 同左 | Mini Media Player / Little Arc Hero Tile 背景 | 固定 |
| `library/card` | `#ffffff0a` | 同左 | 同左 | Easel Card / Space Card (Default は 4% で再指定) | 固定 |
| `library/card-border` | `#ffffff1a` | 同左 | 同左 | Easel Card 枠 / Space Card Hover 枠(10% で再指定) | 固定 |

### content/*  Web コンテンツ領域(ライト)

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `content/bg` | `#f4f4f5` | 同左 | 同左 | Content Area 背景(Web ページのプレースホルダ) | 固定。実装では WKWebView が描画 |
| `content/bar` | `#ffffff` | 同左 | 同左 | ナビバー・カード | 固定 |
| `content/skeleton` | `#e4e4e7` | 同左 | 同左 | スケルトン | 固定 |
| `content/skeleton-strong` | `#d4d4d8` | 同左 | 同左 | スケルトン(強) | 固定 |
| `content/dim` | `#0000008c` | 同左 | 同左 | Command Bar 表示時などのコンテンツ減光 (Dim=On)。用途の厳密な対応は未確認 | 固定 |

### menu/*  New Menu・Easel Toolbar

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `menu/bg` | `#090909` | 同左 | 同左 | New Menu / Little Arc Open Menu / Easel Toolbar 背景 | 固定 |
| `menu/selected` | `#3b3b3b` | 同左 | 同左 | 選択項目 / Add Space Button Default | 固定 |
| `menu/hover` | `#ffffff14` | 同左 | 同左 | Hover (白 8%) | 固定 |
| `menu/pressed` | `#ffffff29` | 同左 | 同左 | Pressed (白 16%) | 固定 |
| `menu/divider` | `#3b3b3b` | 同左 | 同左 | 区切り線 / Easel Toolbar 枠 | 固定 |

### favempty/*  お気に入り空状態

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `favempty/bg` | `#0000001f` | `#1f2035` | `#1a2d2d` | Favorites Empty State 背景 (使用時 12%) | Theme 依存 |
| `favempty/bg-hover` | `#00000033` | `#25263f` | `#203636` | Hover 背景 (20%) / Space Card の Profile Pill | Theme 依存 |
| `favempty/border` | `#ffffff4d` | `#ffffff57` | `#ffffff57` | 破線的な枠 1px (使用時 30%) | Theme 依存 |
| `favempty/star-bg` | `#f0f0f5` | `#eef0ff` | `#eafff8` | 星バッジの円 | Theme 依存 |
| `favempty/star` | `#1e1e1f` | `#26297a` | `#1f6b5e` | 星 | Theme 依存 |

### space/*  Space 切替

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `space/dot-active` | `#ffffff99` | 同左 | 同左 | Space Dot (Active、使用時 60%) | 固定 |
| `space/dot-inactive` | `#ffffff4d` | 同左 | 同左 | Space Dot (Inactive) | 固定 |
| `space/dot-hover` | `#ffffff80` | 同左 | 同左 | Space Dot (Hover) | 固定 |
| `space/window-a` | `#5e5c5c` | `#393a4c` | `#2f4d49` | Space 空状態コンテンツのグラデ始点 | Theme 依存 |
| `space/window-b` | `#5e5c5c` | `#48394c` | `#3f4d3b` | 同グラデ終点 | Theme 依存 |
| `space/label` | `#99999e` | `#9a99a8` | `#9ab3ad` | Space Name Label | Theme 依存 |

### settings/*  Settings・Dialog(Settings 調)

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `settings/window-bg` | `#1e2023` | 同左 | 同左 | Settings Window / Create a Space / Boost Editor 背景 | 固定 |
| `settings/toolbar-bg` | `#26282b` | 同左 | 同左 | Settings ツールバー | 固定 |
| `settings/toolbar-divider` | `#111214` | 同左 | 同左 | ツールバー下線 | 固定 |
| `settings/card-bg` | `#232528` | 同左 | 同左 | Settings Group | 固定 |
| `settings/card-border` | `#2f3134` | 同左 | 同左 | Group 枠 / Text Field 枠 | 固定 |
| `settings/divider` | `#303235` | 同左 | 同左 | 行区切り | 固定 |
| `settings/button-bg` | `#36383b` | 同左 | 同左 | Secondary Button / Slider Track | 固定 |
| `settings/button-hover` | `#414346` | 同左 | 同左 | Secondary Hover | 固定 |
| `settings/button-pressed` | `#4b4d50` | 同左 | 同左 | Secondary Pressed | 固定 |
| `settings/accent` | `#a553a7` | 同左 | 同左 | Primary ボタン・フォーカス枠・Progress・Slider Fill | 固定 |
| `settings/accent-text` | `#b55fc8` | 同左 | 同左 | アクセント文字色(用途の個別確認は未確認) | 固定 |
| `settings/tab-selected` | `#3e4144` | 同左 | 同左 | Settings Tab Selected | 固定 |
| `settings/toggle-on` | `#a553a7` | 同左 | 同左 | Toggle On | 固定 |
| `settings/toggle-on-hover` | `#b162b3` | 同左 | 同左 | Toggle On Hover | 固定 |
| `settings/toggle-off` | `#4a4b4e` | 同左 | 同左 | Toggle Off | 固定 |
| `settings/toggle-off-hover` | `#55565a` | 同左 | 同左 | Toggle Off Hover | 固定 |
| `settings/knob` | `#f2e6f3` | 同左 | 同左 | Toggle ノブ(On) | 固定 |
| `settings/knob-off` | `#d9d9da` | 同左 | 同左 | Toggle ノブ(Off) | 固定 |
| `settings/link` | `#3a84d4` | 同左 | 同左 | リンク(Little Arc の Open here instead) | 固定 |
| `settings/text-primary` | `#e5e5e6` | 同左 | 同左 | Settings 本文 | 固定 |
| `settings/text-secondary` | `#9fa0a3` | 同左 | 同左 | 補足・プレースホルダ | 固定 |
| `settings/text-disabled` | `#5b5c5f` | 同左 | 同左 | 無効テキスト | 固定 |
| `settings/keycap-bg` | `#ffffff` | 同左 | 同左 | Keycap Field 背景 | 固定 |
| `settings/keycap-text` | `#1e1e1f` | 同左 | 同左 | Keycap 文字 | 固定 |
| `settings/list-bg` | `#1c1e20` | 同左 | 同左 | Profiles 一覧背景(想定。用途は未確認) | 固定 |
| `settings/list-selected` | `#34303a` | 同左 | 同左 | Settings Profile Item Selected | 固定 |
| `settings/banner-bg` | `#4b484e` | 同左 | 同左 | Settings Banner | 固定 |
| `settings/field-bg` | `#2b2d30` | 同左 | 同左 | Settings Search Field / Dialog Text Field (Settings) | 固定 |
| `settings/member-card` | `#fffdeb` | 同左 | 同左 | Account Member Card | 固定 |
| `settings/member-ink` | `#5b5470` | 同左 | 同左 | Member Card の文字 | 固定 |
| `settings/status-green` | `#1db31d` | 同左 | 同左 | ステータス緑(用途の個別確認は未確認) | 固定 |
| `settings/title-text` | `#d6d6d7` | 同左 | 同左 | Settings Window タイトル | 固定 |

### dialog/*  Dialog(Space/Profile 調)

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `dialog/bg` | `#151b30` | 同左 | 同左 | Profile Dialog / Little Arc Open Button 背景 | 固定 |
| `dialog/border` | `#2c3350` | 同左 | 同左 | Dialog 枠 / Open Button 内の区切り | 固定 |
| `dialog/field-bg` | `#ffffff08` | 同左 | 同左 | Text Field (Space) 背景 (使用時 3%) | 固定 |
| `dialog/field-border` | `#ffffff17` | 同左 | 同左 | Text Field (Space) 枠 (使用時 9%) | 固定 |
| `dialog/primary` | `#3843fc` | 同左 | 同左 | Dialog Button Blue | 固定 |
| `dialog/primary-muted` | `#1e258a` | 同左 | 同左 | Blue Disabled 背景 | 固定 |
| `dialog/primary-muted-text` | `#4d54a6` | 同左 | 同左 | Blue Disabled 文字(想定。個別確認は未確認) | 固定 |
| `dialog/secondary` | `#30305f` | 同左 | 同左 | Dialog Button Indigo | 固定 |
| `dialog/secondary-border` | `#5a58a8` | 同左 | 同左 | Indigo 枠 1px | 固定 |
| `dialog/chip` | `#ffffff38` | 同左 | 同左 | Key Chip 背景 (使用時 22%) | 固定 |
| `dialog/text` | `#ffffff` | 同左 | 同左 | Dialog 文字 | 固定 |
| `dialog/text-muted` | `#b9bdd4` | 同左 | 同左 | Dialog 補足文字 | 固定 |
| `dialog/caret` | `#c04ad8` | 同左 | 同左 | キャレット色(用途は未確認) | 固定 |
| `dialog/avatar` | `#5a58b0` | 同左 | 同左 | Profile Avatar の顔 | 固定 |
| `dialog/badge` | `#3aa43a` | 同左 | 同左 | Avatar の + バッジ | 固定 |

### little/*  Little Arc

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `little/toolbar-bg` | `#342e48` | 同左 | 同左 | Little Arc Toolbar 背景 | 固定 |
| `little/toolbar-border` | `#00000073` | 同左 | 同左 | ツールバー下線 (使用時 45%) | 固定 |
| `little/pill-bg` | `#ffffff14` | 同左 | 同左 | Profile Pill (使用時 8%) | 固定 |

### search/*  Choco Search(変数のみ)

| token | Dark | Space – Indigo | Space – Teal | 用途 | SwiftUI |
|---|---|---|---|---|---|
| `search/accent-soft` | `#a553a71f` | 同左 | 同左 | 検索ページ用。対応コンポーネントがファイル内に無く未確認 | 固定 |
| `search/accent-ink` | `#733080` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/border` | `#1a142417` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/text-secondary` | `#4f4d59` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/text-muted` | `#807d8c` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/chip-bg` | `#1a14240d` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/ai-bg` | `#f4ebf6` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/skeleton` | `#e3e3e7` | 同左 | 同左 | 同上(未確認) | 固定 |
| `search/page-bg` | `#f3f0f6` | 同左 | 同左 | 同上(未確認) | 固定 |

**変数数**: Arc Tokens 116 = 色 110(上表に全掲載) + `radius/*` 5(§5) + `space/sidebar-pad` 1(§4。エイリアス)。

---

## 8. グラデーション(リテラル、変数化されていない)

| 箇所 | 値 |
|---|---|
| Space Card Gradient / Default | `#252538` → `#362438` |
| Space Card Gradient / Hover | `#303047` → `#422e45`(+ 1px `library/card-border` 10%) |
| Content Area – Space(Indigo の空) | `#393a4c` → `#48394c`(= `space/window-a` → `space/window-b` の Indigo 値) |
| Account Member Card アーチ | `#c75480` → `#8c4d9e` → `#edb2b8` |
| Boost Color Wheel | Hue: `#ff3b30 #ffcc00 #34c759 #00c7be #0a84ff #bf5af2` 循環 + 白の放射グラデ |

---

## 9. レイアウト寸法

### ウィンドウ・領域(メイン画面 `1a Main`)
| 項目 | 値 |
|---|---|
| ウィンドウ | **2094 × 1127**、角丸 10、枠 1px `#ffffff` 8%、影 §6 |
| Sidebar | 幅 **200**、高さ 1127(ウィンドウ全高)、内側 padding 左右 8 → コンテンツ幅 **184** |
| Content Area | x=199, y=8、**1887 × 1111**、角丸 6、背景 `content/bg`(右・下余白 8) |
| Content Area の余白 | 上 8 / 右 8 / 下 8 / Sidebar との間 −1(x=199、Sidebar 幅 200 と 1px 重なる) |
| Space Lists | x=8, y=74、184 × 970(Space 1: 184 × 408, Space 2: 184 × 264) |
| Command Bar | 668 × 283、ウィンドウ内 x=713, y=416 付近(中央やや上) |
| Site Controls Popover | 220 × 366 |
| New Menu | 184 × 258(`1e` フレーム。x=15, y=834) |
| Recent Files | 184 × 188(x=8, y=899) |

### 状態別
| 画面 | 寸法 |
|---|---|
| `1b` Sidebar hidden | Content Area がほぼ全面(x=8, 幅 2078)。サイドバーは非表示 |
| `1c` Sidebar peek | Sidebar を x=6, y=6、**200 × 1115**、角丸 10、枠 `#ffffff` 10%、影 0/10/32 45% で重ねる。Content Area は x=8, 2078 × 1111 |
| `2` Library | Library Rail **96** + Library Panel **266** (x=96) + Content Area (x=363, y=8) **1723 × 1111**。Panel padding 10 / 8 / 0 / 8、ヘッダ 250 × 26 |
| `2a` Spaces 一覧 | Rail 96 + Spaces Scroller **544**(x=96)+ Content Area (x=648, y=8) **1438 × 1111**。カード **208 × 1041**、行 gap 20(x=28, y=43)、2c では 1 枚 228 ピッチ、Scroll Fade 幅 64、Scroll Indicator 156 × 5 |
| Settings Window | **684 × 650**(ツールバー 88 + 本文 562)、角丸 10 |
| Little Arc | 外枠 1100 × 780、Window **940 × 620**(x=80, y=80)、角丸 12、Toolbar 高さ **36**、本文 938 × 582 |
| Create a Space(ポップアップ) | 440 × 319(padding 24, gap 20) |
| Create Profile | 390 × 371 |
| Boost Editor | 320 × 624(padding 16, gap 16)、Color Wheel 168 × 168 |

### アイコン・小要素
| 項目 | 値 |
|---|---|
| `Icon/*` 基本 | **16 × 16**、stroke 1.2、round cap |
| アイコン実使用サイズ | 9〜20(chevron 12、search 13〜14、favicon 14〜16、Library Nav 20、Space Dot 内 14、Settings Tab Icon 22、Library Empty 32)。opacity 0.4〜0.9(§10) |
| Favicon | 16 × 16(12 種) |
| Window Controls | 52 × 12(円 12 × 12、gap 8) |
| Toolbar Icon Button | 28 × 28 |
| Sidebar Bottom Button | 26 × 26 |
| Space Dot | 26 × 26(アイコン 14、active indicator 10 × 2) |
| Mini Media Player | 184 × 28 |

---

## 10. コンポーネント別仕様

凡例: H/V = 横/縦 auto-layout、padding は 上/右/下/左(または 縦/横)、サイズは px = pt。fill は変数名(`@N%` は変数 alpha ではなく **使用時の不透明度**)。

### Sidebar 系
| コンポーネント | サイズ | レイアウト | 角丸 | 色 / 文字 / アイコン |
|---|---|---|---|---|
| Window Controls | 52×12 | H gap 8、円 12×12 | 円 | Inactive: `window/traffic-inactive` |
| Toolbar Icon Button | 28×28 | – | 6 | icon 16 @0.62。Hover: `sidebar/hover`、Pressed: `sidebar/selected`、Disabled: opacity 0.35 |
| Sidebar URL Field | 184×32 | H gap 6、padding 0/6/0/10 | 8 | fill `sidebar/field`(使用時 7%)。search icon 13 @0.55、`Sidebar/Field` + `text/tertiary`。Hover/Selected あり |
| Favorite Tile | 56×40 | – | 8 | fill `sidebar/tile`(6%)。Hover `sidebar/field`(白で明るくなるだけ)、Selected `sidebar/selected` + Favicon 色の枠 1.5(70%)、Selected 中の Hover は背景に Favicon 色 15% を重ねる、Pressed opacity 0.92。favicon 14。1 行 6 個 gap 8(184 幅) |
| Sidebar Folder Row | 184×32 | H gap 8、padding 0/10/0/10 | 8 | chevron 12 @0.6、`Sidebar/Tab Title` + `text/secondary`。Hover `sidebar/hover`、Pressed `sidebar/selected` |
| Sidebar Divider | 184×16 | H gap 6、padding 0/4/0/4 | – | 線 1px `sidebar/divider`(15%)。Clear ボタン 39×14(arrow-down 9 + `Sidebar/Caption`)、opacity 0.75 |
| New Tab Row | 184×32 | H gap 6、padding 0/10/0/10 | 8 | アイコン枠 16(plus 11 @0.75)、`Sidebar/Tab Title` + `text/primary`。Selected: `sidebar/selected` (12%) |
| Tab Row | 184×32 | H gap 6、padding 0/6/0/10 | 8 | favicon 16、ラベル 13/Medium `text/primary`、Close ボタン 20×20 r5(既定で非表示、icon 12 @0.7)。Tab 間 gap 4 |
| Update Pill | 184×22 | 中央揃え | 11 | fill `sidebar/field`(7%)、`Pill/Label` + `text/primary` |
| Sidebar Bottom Button | 26×26 | – | 6 | icon 16 @0.7。Open False/True、Hover/Pressed あり |
| Mini Media Player | 184×28 | padding 0/10/0/10 | 8 | fill `media/bg`。favicon 16、prev/next 13 @0.4、play 14 @0.85、volume 15 @0.85 |
| Space Name Label | 184×28 | padding 0/10/0/10 | – | `Library/Section` + `space/label` |
| Space Dot / Space Dots | 26×26 / 56〜116×26 | gap 4(Dots) | 8 | 全 Space がアイコン 14(Active @1.0、Inactive @0.4)。Active の下に indicator 10×2 r1 `space/dot-active`(60%) を y=22 に置き、切替で次のドットへスプリングでスライド(163:7447) |
| Favorites Empty State | 184×81 | V gap 2、padding 12/12/8/12 | 10 | fill `favempty/bg`(12%、Hover は `favempty/bg-hover` 20%)、枠 1px `favempty/border`(30%)。星バッジ 16(星 9)、Title `Favorites/Empty Title`、Sub `Favorites/Empty Sub`、dismiss 20×20(×8)。Dismissed: 高さ 1、opacity 0 |
| Sidebar Folder Name Field | 184×32 | H gap 8、padding 0/10/0/10 | 内側 6 | 内側 Field 140×24、枠 1.5 `settings/accent`、fill `sidebar/field`(7%)、選択ハイライト `settings/accent` r3 |
| Arc Sidebar(全体) | 200×1127 | V gap 6、padding 2/8/12/8 | – | 上部 Top Bar 184×28(padding 0/0/0/6): Window Controls → Toggle → Back/Forward → Reload |

### Command Bar
| 要素 | 値 |
|---|---|
| Command Bar | **668×283**、V、角丸 10(`radius/cmd`)、fill `cmd/bg`、枠 1px `cmd/border`(inside)、影 0/16/48 45% |
| 入力行 | 高さ 52、H gap 10、padding 0/14/0/18。search icon 14 @0.8、`Command/Input` + `cmd/placeholder`、info ボタン 22×22 r11 黒・icon 16 @0.85 |
| 区切り | 1px `cmd/separator` |
| 結果リスト | V gap 1、padding 6/6/8/6 |
| Result Row | 656×42、H gap 10、padding 0/6/0/10、角丸 8。favicon 16、`Command/Row` + `cmd/text`。右: アクション領域 109×22 gap 8(`Command/Action` + `cmd/action-dim`、矢印ボタン 22×22 r4 `cmd/arrow-bg`、icon 14 @0.6)。Selected: `cmd/selected`、Hover: `#2e2e2f` |

### Library
| コンポーネント | サイズ | 値 |
|---|---|---|
| Library Rail | 96×1127 | Window Controls + Nav(70×426, V gap 18) + Back/Globe ボタン 26×26 |
| Library Nav Item | 70×56 | V gap 4、角丸 8。icon 20 @0.7、`Library/Nav Label` + `text/secondary`。Hover/Selected/Pressed fill あり |
| Library Search Field | 200×26 | H gap 6、padding 0/8/0/8、r8、`sidebar/field`。search icon 13 @0.6。Focused: `sidebar/selected` |
| Filter Button | 64×26 | H gap 4、padding 0/8/0/6、r6。icon 14 @0.7、`Library/Title` |
| List Section Header | 200×24 | padding 0/0/0/8、`Library/Section` |
| Archive Row | 200×44 | H gap 10、padding 0/6/0/8、r8。favicon 16、タイトル `Library/Title` + URL `Library/Subtitle`(gap 1)、アクション 22×22 r5(icon 13 @0.8) |
| Download Row | 200×46 | gap 10、padding 0/6/0/8、r8。サムネ 24×30 |
| Easel Card | 104×104 | V、padding 6、r12、fill `library/card`。内側 92×92 r8 + 1px `library/card-border`、padding 0/8/8/8、gap 4。バッジ 14、`Library/Section`。Hover: `sidebar/hover` |
| Library Empty State | 220×137 | V gap 8。icon 32 @0.55、見出し 13/SemiBold、本文 `Library/Subtitle` + `text/secondary`、Learn more ボタン 81×22 r6(`sidebar/field` 7%、`Pill/Label`) |

### Site Controls Popover
| 要素 | 値 |
|---|---|
| Popover | **220×366**、V gap 6、padding 8、r12、fill `popover/bg`(95%)、枠 1px `#ffffff` 18%、効果: 背景ブラー 30 + 影 0/10/30 35% |
| クイックアクション行 | 高さ 26、gap 8、4 ボタン(Popover Icon Button 42×26 r7 `popover/tile`、icon 15 @0.9。実配置 44.5 幅) |
| 拡張機能行 | gap 8、Extension Tile 42×26 r7 `popover/field`(hover = `popover/icon-circle` 20%) |
| Section Header | 204×22、`Popover/Section` |
| Settings Row | 204×40、gap 8、r8。アイコン円 28×28 r14 `popover/icon-circle`(icon 15)、タイトル `Popover/Row Title` + サブ `Popover/Row Subtitle`(gap 0) |
| Footer | 204×28。セキュリティ pill 79×26(gap 4、padding 0/10/0/8、r7、lock 12 @0.85)、more ボタン 26×26 r13(icon 14) |

### New Menu / 他のメニュー
| コンポーネント | 値 |
|---|---|
| New Menu | 184×258、V、padding 6、r12、fill `menu/bg`、影 0/8/24 45%。上部に尾 12×6(`menu/bg`) |
| New Menu Item | 172×36、H gap 6、padding 0/10/0/10、r8。icon 16、`Command/Row` + `text/primary`、ショートカット 12/Medium `text/tertiary`。Hover `menu/hover`、Selected `menu/selected`、Pressed `menu/pressed` |
| New Menu Divider | 172×15、padding 0/4/0/4、線 1px `menu/divider` |
| Little Arc Open Menu | 232×171、V、padding 6、r12、fill `menu/bg`、影 0/8/24 45%。項目 220×36 |
| Easel Toolbar | 225×42、H gap 2、padding 6、r12、`menu/bg` + 枠 1px `menu/divider`、影 0/8/24 45%。ボタン 28×28(Toolbar Icon Button)、区切り 1×20 |
| Recent File Row | 184×44、H gap 10、padding 6/8/6/6、r8。サムネ 36×32、タイトル 12/Regular `text/primary`、時刻 12/Regular `text/secondary`(gap 1)。Stack 184×188 gap 4 |

### Settings 系
| コンポーネント | 値 |
|---|---|
| Settings Window | **684×650**、r10、fill `settings/window-bg`、枠 1px `#ffffff` 12%、影 §6。Toolbar 684×88(`settings/toolbar-bg`、下線 1px `settings/toolbar-divider`)、タイトル `Settings/Title` + `settings/title-text` |
| Settings Tab | 57×48(Selected は 59×50)、V gap 4、padding 4/8/4/8、r6。Icon 22(stroke 1.467)、`Settings/Tab`。Hover: 白 5%、Selected: `settings/tab-selected` + 1px 白 8% |
| Settings Group | 幅 556、V、padding 左右 10、r8、fill `settings/card-bg`、枠 1px `settings/card-border` |
| Settings Row | 536×36、H gap 8、padding 8/0/8/0。ラベル `Settings/Body` + `settings/text-primary`、サブ `Settings/Caption` + `settings/text-secondary`。Type: Toggle / Button / Select / Arrow / Keycap / Text |
| Settings Toggle | **36×20**、r10、ノブ 18×18 r9。On: `settings/toggle-on`(hover `toggle-on-hover`)、Off: `settings/toggle-off`(hover `toggle-off-hover`)、ノブ `settings/knob` / `knob-off`、影 0/1/2 25% |
| Settings Secondary Button | 87×24、H gap 6、padding 0/12/0/12、r6、`settings/button-bg`(Hover `button-hover`、Pressed `button-pressed`)、`Settings/Body Medium` |
| Settings Popup Select | 144×24、gap 6、padding 0/8/0/10、r6 |
| Settings Keycap Field | 62×22、r5、fill `settings/keycap-bg`、枠 1px #000 15%。Recording: 枠 2px `settings/accent`。`Settings/Keycap` |
| Settings Search Field | 340×36、H gap 8、padding 0/14/0/14、上のみ r8、`settings/field-bg`。search icon 16 |
| Accent Pill Button | 219×24、gap 6、padding 0/10/0/6、r5、`settings/accent`。⌘ バッジ 14×14(白 90%) + `Settings/Body Medium` 白 |
| Settings Banner | 376×32、gap 10、padding 4/4/4/16、r6、`settings/banner-bg` |
| Settings Profile Item | 173×32、gap 6、padding 0/6/0/6、r6。Selected: `settings/list-selected` |
| Settings List Bottom Bar | 205×30、上線 1px `settings/divider`、ボタン 32×30、区切り 1×16 |
| Account Member Card | 240×360、r4、`settings/member-card`。アーチ 208×192 |
| Settings Square Icon | 20×20、r5(色はアプリごとの個別色) |

### Dialog / Editor 系
| コンポーネント | 値 |
|---|---|
| Dialog Button | 高さ **32**、H gap 8、padding 0/16/0/16、r8、`Settings/Body Medium`。Type: **Primary**(`settings/accent`)/ **Secondary**(`settings/button-bg`、hover `-hover`、pressed `-pressed`)/ **Blue**(`dialog/primary`、Disabled `dialog/primary-muted`)/ **Indigo**(`dialog/secondary` + 枠 1px `dialog/secondary-border`)。Hover/Pressed/Disabled の個別 fill は Primary/Secondary 以外 **未確認**。Show Key で Key Chip を右に表示 |
| Dialog Text Field | Settings 調: **300×36**、r8、`settings/field-bg`、枠 1px `settings/card-border`(Focused は 2px `settings/accent`)、padding 0/12/0/12。Space 調: **300×40**、`dialog/field-bg`(3%)、枠 1px `dialog/field-border`(9%) |
| Key Chip | Text: 31×16、padding 2/6/2/6、r4、`dialog/chip`(22%)、`Dialog/Key`。Return: 24×18、枠 1px `dialog/text` |
| Color Swatch | 32×32、padding 4、r16、内円 24。Selected: 枠 2px `settings/text-primary` |
| Dialog Slider | 288×20、Track 高さ 4 `settings/button-bg`、Fill `settings/accent`、Thumb 16×16 白 + 影 0/1/3 40% |
| Create a Space ダイアログ | 440×319、V gap 20、padding 24、r10。タイトル `Dialog/Title`、Name 行 36 高(アイコンボタン 36×36 + Text Field 346×36)、Color 行、Profile 行(24 高、Select 144×24)、フッタ 32 高 |
| Create Space(サイドバー内パネル) | 176×236、V gap 8、イラスト 56×40、Title `Sidebar/Create Title`、Fields 176×108(行 176×32、`sidebar/field` 9%、gap 6)、Create ボタン 176×32(`dialog/primary-muted`)、Cancel リンク |
| Profile Dialog | 390×371、V gap 12、padding 32/32/24/32、r12、`dialog/bg`、枠 1px `dialog/border`、影 §6。Avatar 56×56、Title `Dialog/Heading`、本文 `Dialog/Body` + `dialog/text-muted`、フッタ 44 高(padding-top 12、gap 8) |
| Boost Editor | 320×624、V gap 16、padding 16、r10。Tab 4 つ 286×50、Color Wheel 168、スライダ ×2、Mode ボタン 90×32 ×3、フッタ 32 |

### Space Card(Spaces 一覧)
| 要素 | 値 |
|---|---|
| Space Card | **208×1041**、V、r14。Theme Default: `library/card`(4%)、Hover: `sidebar/field`(7%) + 1px `library/card-border`(10%)。Gradient: §8 |
| Header | 208×38、H gap 12、padding 0/16/0/8。名前 `Library/Section` + `text/secondary`、space icon 16、Profile Pill 63×19 r10(`favempty/bg-hover` 20%、face 11、`Dialog/Note`)、編集アイコン 13 |
| Tab List | 208×965、V、padding 4/8/0/8 |
| Space Card Row | Folder 192×26 / Tab 192×36 / Tab Subtitle 192×36、H gap 8、padding 0/6/0/6(Subtitle は右 20)、r8。Folder 名 `Command/Action`、タイトル `Dialog/Body Medium`、サブ `Dialog/Note` + `text/tertiary` |
| Footer | 208×38、padding 0/12/0/12、move・more アイコン 14 |
| Add Space Button | 22×22 円。Default `menu/selected` / Hover `cmd/selected` / Pressed `popover/tile`。plus 12 |

### Little Arc
| 要素 | 値 |
|---|---|
| Little Arc Toolbar | **940×36**、H gap 12、padding 0/6/0/12、fill `little/toolbar-bg`、下線 1px `little/toolbar-border`(45%)。Window Controls(Inactive) → Profile Pill 69×18(r6、`little/pill-bg` 8%、face 12、`Pill/Label`)→ Domain(`Dialog/Body Medium` + `text/tertiary`、中央)→ Capture/Copy Link(24×24 r6)→ Open in Main ボタン。Loading 時: Progress 2px `settings/accent` |
| Little Arc Open Button | 149×24、r6、`dialog/bg`。Main Action(padding 0/6/0/8、gap 4)+ 区切り 1×14 + Dropdown 24×24(chevron-down 16 @0.75)。文字: "Open in" `Dialog/Body Medium` `dialog/text-muted`、Space 名 `Command/Action` `dialog/text` |
| 本文 | Hero Tile 110×110 r26(`media/bg`)、タイトル `Dialog/Title` `text/on-light`、リンク `Dialog/Body Medium` `settings/link`、gap 24 |

### Search(Choco Search)
**未確認**。Figma ファイルに画面・コンポーネントが存在しないため、寸法・余白・タイポは未取得です。`search/*` 変数(§7)のみ参照可能です。

---

## 11. アニメーション

Figma のプロトタイプ反応から実測した値です。

### 共通イージング
| 名前 | 値 | SwiftUI |
|---|---|---|
| 標準 ease | `cubic-bezier(0.2, 0.8, 0.2, 1)` | `.timingCurve(0.2, 0.8, 0.2, 1, duration: d)` |
| Spring | mass 1 / stiffness 420 / damping 28(**bounce ≈ 0.317**、ζ ≈ 0.683、response ≈ 0.307s) | `.spring(duration: 0.307, bounce: 0.317)` または `.interpolatingSpring(mass: 1, stiffness: 420, damping: 28)` |

### 画面遷移ごとの duration(Smart Animate)
| 遷移 | duration | easing |
|---|---|---|
| Command Bar を開く(`1a` → `1`) | **320ms** | Spring |
| Command Bar を閉じる(`1` → `1a`) | **160ms** | cubic-bezier |
| Site Controls を閉じる(`3` → `1a`) | 160ms | cubic-bezier |
| Sidebar を隠す(`1a` → `1b`) | 200ms | cubic-bezier |
| Sidebar を再表示(`1b` → `1a`) | 300ms | Spring |
| Sidebar peek 終了(`1c` → `1a`) | 300ms | Spring |
| Library 表示から戻る(`2`・`4`・`5`・`6` → `1a`) | 200ms | cubic-bezier |
| New menu を閉じる(`1e` → `1a`) | 160ms | cubic-bezier |
| New menu → Command Bar(`1e` → `1`) | 320ms | Spring |
| Space 切替(`1g` → `1a`, `1a` → `1g`) | 320ms | Spring |
| Settings を開く(`1a` → `105:16403`) | 200ms | Dissolve + ease-out |
| New folder / easel / split / Space(`1e-*` → `1a`) | 300ms | cubic-bezier |
| Spaces 一覧(`2a`・`2b`・`2c` ⇄ `1a` など) | 300ms | cubic-bezier |
| Little Arc: 読込 → 通常ページ | 450ms(1.2s 後に自動) | cubic-bezier |
| Little Arc: ページ → 次状態 | 300ms | cubic-bezier |
| Little Arc: Open in Main メニュー | 200ms / 300ms | cubic-bezier |
| Little Arc → メインへ移動 | **400ms**(0.2s 後に自動、Dissolve) | cubic-bezier |
| タブをドラッグしてブックマーク(Lift / Over / Drop / Added) | 450ms / 400ms(Spring) / 400ms / 300ms | 各 cubic-bezier / Spring |

- ON_KEY_DOWN トリガは Figma 上のデモ操作のキーです(実装では対応するイベントに置き換え)。
- Hover / Pressed の色変化の個別 duration は **未確認**(Figma のバリアントは状態のみで、時間は未設定)。

---

## 12. 既知の例外

- **Command Bar と Site Controls Popover は 0.96 倍のスケール**で配置されているフレームがあります(`1a` / `1e` / `1c` / `1e-1` 等の「閉じた状態」インスタンス。opacity 0 の隠し要素)。
  - Command Bar: 641.3×271.7(= 668 × 0.96)、Popover: 211.2×351.4(= 220 × 0.96)。
  - 内部の余白・角丸・文字(7.68, 9.6, 11.52, 6.72, 13.44 / 10.56, 11.52, 12.48, 16.32 など)も同率に縮み、**rem のスケールに乗りません**。
  - **これらは rem に無理に揃えない**。実装の基準は **コンポーネント定義(スケール 1.0)** の値(668×283、220×366 など、本書 §10)です。これらの 0.96 倍インスタンスは「閉じた状態(opacity 0)」で置かれており、開閉アニメーションの開始/終了スケールとして使われている可能性が高いですが(**推定。Figma からは断定できず未確認**)、静止状態の寸法としては 1.0 の値を使ってください。
- 同様に、旧 Settings Window のゴースト(670.3×637、0.98 倍)は **非表示・未使用**(`【旧】`プレフィックス)。無視してください。
- Content Area の x は 199(Sidebar 幅 200 と 1px 重なる)。実装では Sidebar 200 + 余白 8 の分離で組んでも問題ありません。
- スケール 1.0 のフレーム(`1`、`3`)では Command Bar 668×283 / Popover 220×366。
- `search/*` 変数は存在するが画面なし(§1)。
- Space Card Row のサブタイトル付きは右 padding 20。通常 Tab は 6。
- `sidebar/divider` の変数値は `#ffffff26`(15%)。Divider の線のインスタンスは fill `sidebar/divider` に `@15%` と表示されています(変数 alpha をそのまま表示した値と解釈。乗算かどうかは未確認)。

---

## 13. SwiftUI 実装メモ

### Spacing(`Spacing (rem)` と同値)
```swift
import SwiftUI

/// 1rem = 16pt。Figma の `Spacing (rem)` 変数と同値。
enum Spacing {
    static let rem: CGFloat = 16

    static let s0: CGFloat       = 0              // space/0
    static let s0_0625: CGFloat  = 0.0625 * rem   // 1   space/0_0625 (hairline)
    static let s0_125: CGFloat   = 0.125  * rem   // 2
    static let s0_25: CGFloat    = 0.25   * rem   // 4
    static let s0_375: CGFloat   = 0.375  * rem   // 6
    static let s0_5: CGFloat     = 0.5    * rem   // 8   (= sidebarPad)
    static let s0_625: CGFloat   = 0.625  * rem   // 10
    static let s0_75: CGFloat    = 0.75   * rem   // 12
    static let s0_875: CGFloat   = 0.875  * rem   // 14
    static let s1: CGFloat       = 1      * rem   // 16
    static let s1_125: CGFloat   = 1.125  * rem   // 18
    static let s1_25: CGFloat    = 1.25   * rem   // 20
    static let s1_5: CGFloat     = 1.5    * rem   // 24
    static let s2: CGFloat       = 2      * rem   // 32
    static let s2_5: CGFloat     = 2.5    * rem   // 40
    static let s3: CGFloat       = 3      * rem   // 48
    static let s3_75: CGFloat    = 3.75   * rem   // 60
    static let s5: CGFloat       = 5      * rem   // 80

    static let sidebarPad = s0_5                  // space/sidebar-pad
}

enum Radius {
    static let row: CGFloat = 8      // radius/row
    static let tile: CGFloat = 8     // radius/tile
    static let field: CGFloat = 8    // radius/field
    static let cmd: CGFloat = 10     // radius/cmd
    static let popover: CGFloat = 12 // radius/popover
    static let card: CGFloat = 14    // Space Card
    static let window: CGFloat = 10
    static let content: CGFloat = 6  // Content Area
}

enum Layout {
    static let sidebarWidth: CGFloat = 200
    static let sidebarContentWidth: CGFloat = 184
    static let contentInset: CGFloat = 8
    static let libraryRail: CGFloat = 96
    static let libraryPanel: CGFloat = 266
    static let rowHeight: CGFloat = 32
    static let toolbarButton: CGFloat = 28
    static let commandBarSize = CGSize(width: 668, height: 283)
    static let popoverSize = CGSize(width: 220, height: 366)
}

enum Motion {
    static let ease = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.2)
    static let spring = Animation.interpolatingSpring(mass: 1, stiffness: 420, damping: 28)
    // 等価: .spring(duration: 0.307, bounce: 0.317)
}
```

### Color extension(8 桁 hex = `#RRGGBBAA`)
```swift
import SwiftUI

extension Color {
    /// "5e5c5c" / "#5e5c5c" / "ffffff12"(RRGGBBAA)
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xff) / 255; g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255;  a = Double(v & 0xff) / 255
        } else {
            r = Double((v >> 16) & 0xff) / 255; g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255;         a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum SpaceTheme { case dark, indigo, teal }   // Arc Tokens のモード

enum ArcColor {
    // 固定トークン
    static let textPrimary   = Color(hex: "ededed")
    static let textSecondary = Color(hex: "b9b8b8")
    static let textTertiary  = Color(hex: "8f8e8e")
    static let cmdBg         = Color(hex: "1e1e1f")
    static let cmdBorder     = Color(hex: "4f4d4c")
    static let menuBg        = Color(hex: "090909")
    static let settingsAccent = Color(hex: "a553a7")
    static let dialogPrimary = Color(hex: "3843fc")

    // Theme 依存トークン(例)
    static func sidebarBg(_ t: SpaceTheme) -> Color {
        switch t { case .dark: Color(hex: "5e5c5c"); case .indigo: Color(hex: "262538"); case .teal: Color(hex: "213a3a") }
    }
    static func sidebarField(_ t: SpaceTheme) -> Color {
        switch t { case .dark: Color(hex: "ffffff12"); default: Color(hex: "ffffff17") }
    }
    static func favEmptyBg(_ t: SpaceTheme) -> Color {
        switch t { case .dark: Color(hex: "0000001f"); case .indigo: Color(hex: "1f2035"); case .teal: Color(hex: "1a2d2d") }
    }
}
```
- 追加トークンは §7 の表から同じパターンで機械的に起こせます(`Theme 依存` のみ関数、他は `static let`)。
- **不透明度の再指定**(例: `sidebar/field` を 7% として使う)は `Color(hex:).opacity(...)` ではなく、**変数の alpha に対する使用時の不透明度**です。`@N%` を見落とさないでください。Figma 上の「使用時 N%」は fill の opacity で、変数自体の alpha に **乗算**されます。実装時は最終見た目を Figma と比較して調整してください(乗算か置換かの判定は **未確認**)。

### フォント
```swift
extension Font {
    static let sidebarTabTitle = Font.system(size: 13, weight: .medium)
    static let commandInput    = Font.system(size: 17, weight: .medium)
    static let commandRow      = Font.system(size: 13, weight: .semibold)
    static let settingsBody    = Font.system(size: 13)
    static let dialogHeading   = Font.system(size: 15, weight: .bold)
    // 他は §3 の表に従う
}
```

### 影(目安。radius = Figma blur ÷ 2)
```swift
extension View {
    func windowShadow()  -> some View { shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 18) }
    func commandShadow() -> some View { shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 16) }
    func popoverShadow() -> some View { shadow(color: .black.opacity(0.35), radius: 15, x: 0, y: 10) }
    func menuShadow()    -> some View { shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 8) }
}
```

### 注意
- Figma は 1x の px。Retina は SwiftUI が処理するため **値をそのまま pt として**使ってください。
- Content Area は WebKit(WKWebView)描画なので `content/*` は**プレースホルダの配色**です(アプリ内の UI 色ではない)。
- 影 `Background blur` は `NSVisualEffectView`(`.hudWindow` / `.popover` 等)で近似できますが、見た目の一致は **未確認**です。
