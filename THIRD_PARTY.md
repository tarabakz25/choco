# Design assets and fonts

The interface follows the user-provided [Figma design](https://www.figma.com/design/ZF9ydApZS6Ln3SRZFO2dWk?node-id=14-1052).

Original exported SVG icons are retained alongside faithful PDF conversions in `Sources/BrowserApp/Resources/Design`. The asset manifest records their source layers and original dimensions. Screenshots and the example personal tab/history data from the design are not application assets.

Settings popup exports are retained in `Sources/BrowserApp/Resources/Settings`, with their source nodes, download sources, and original vector dimensions recorded in `settings-asset-manifest.json`. The window uses native macOS window controls.

Inter and Noto Sans JP are bundled from the official [Google Fonts repository](https://github.com/google/fonts). Both fonts use the SIL Open Font License 1.1; their original license notices are in `Sources/BrowserApp/Resources/Fonts`. The app registers these fonts only for its own process. Site/service logos retain their respective ownership.

The default Space icon is the official Google Material Icons `language` vector, licensed under Apache License 2.0. Its original SVG, faithful PDF conversion and license are bundled in `Sources/BrowserApp/Resources/Material`.
