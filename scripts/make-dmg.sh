#!/bin/bash
# リリースビルドして配布用 DMG と SHA256 を build/ に作成する。
#
# 環境変数（すべて任意）:
#   VERSION            バージョン文字列。未指定なら Info.plist の値
#   BUILD_NUMBER       CFBundleVersion
#   DEVELOPER_ID_APP   例: "Developer ID Application: Name (TEAMID)"。指定時は Developer ID 署名
#   NOTARY_PROFILE     `xcrun notarytool store-credentials` で保存したプロファイル名。指定時は公証＋staple
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${NOTARY_PROFILE:-}" ] && [ -z "${DEVELOPER_ID_APP:-}" ]; then
  echo 'NOTARY_PROFILE を使うには DEVELOPER_ID_APP も必要です。' >&2
  exit 2
fi

./scripts/build-app.sh release

app="build/choco-browser.app"
version="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")}"
dmg="build/choco-browser-$version.dmg"
volume="choco-browser $version"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/choco-browser.app"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
hdiutil create -volname "$volume" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null

if [ -n "${DEVELOPER_ID_APP:-}" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID_APP" "$dmg"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
fi

hdiutil verify "$dmg" >/dev/null
(cd build && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")

if [ -z "${DEVELOPER_ID_APP:-}" ]; then
  signing='ad-hoc（初回起動はシステム設定の「このまま開く」が必要）'
elif [ -z "${NOTARY_PROFILE:-}" ]; then
  signing='Developer ID（未公証）'
else
  signing='Developer ID + 公証済み'
fi
printf '\nDMG: %s\nSHA256: %s.sha256\n署名: %s\n' "$dmg" "$dmg" "$signing"
