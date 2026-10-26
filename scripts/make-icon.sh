#!/bin/bash
# 仮アプリアイコンを生成する: AppSupport/AppIcon.icns と site/assets/icon.png
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"

# 1度コンパイルしてから各サイズを描画する
swiftc -O scripts/make-icon.swift -o "$work/make-icon"
render() { "$work/make-icon" "$iconset/$1" "$2"; }
render icon_16x16.png 16
render icon_16x16@2x.png 32
render icon_32x32.png 32
render icon_32x32@2x.png 64
render icon_128x128.png 128
render icon_128x128@2x.png 256
render icon_256x256.png 256
render icon_256x256@2x.png 512
render icon_512x512.png 512
render icon_512x512@2x.png 1024

iconutil -c icns "$iconset" -o AppSupport/AppIcon.icns
mkdir -p site/assets
cp "$iconset/icon_512x512.png" site/assets/icon.png
printf 'Generated: AppSupport/AppIcon.icns, site/assets/icon.png\n'
