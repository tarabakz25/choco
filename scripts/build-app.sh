#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
case "$configuration" in debug|release) ;; *) echo 'Usage: scripts/build-app.sh [debug|release]' >&2; exit 2;; esac
mkdir -p .build/cache .build/config .build/security .build/ModuleCache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security -c "$configuration" --product choco-browser
binary_directory="$(swift build --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security -c "$configuration" --show-bin-path)"
app_directory="$PWD/build/choco-browser.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$binary_directory/choco-browser" "$app_directory/Contents/MacOS/choco-browser"
resource_bundle="$binary_directory/choco-browser_BrowserApp.bundle"
if [ ! -d "$resource_bundle" ]; then echo "Missing application resources: $resource_bundle" >&2; exit 1; fi
ditto "$resource_bundle" "$app_directory/Contents/Resources/choco-browser_BrowserApp.bundle"
cp -R "$binary_directory/choco-browser_BrowserLocalization.bundle" "$app_directory/Contents/Resources/"
cp -R AppSupport/ja.lproj AppSupport/en.lproj "$app_directory/Contents/Resources/"
cp AppSupport/Info.plist "$app_directory/Contents/Info.plist"
codesign --force --sign - --entitlements AppSupport/choco-browser.entitlements "$app_directory"
printf '\nBuilt: %s\nLaunch: open "%s"\n' "$app_directory" "$app_directory"
