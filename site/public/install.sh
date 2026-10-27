#!/usr/bin/env bash
# choco-browser installer for macOS (Apple Silicon).
#
#   curl -fsSL https://tarabakz25.github.io/choco/install.sh | bash
#
# Downloads the latest release DMG, verifies its SHA-256, copies the app to
# /Applications and clears the quarantine flag. Read it before you run it.
#
# Overrides (all optional):
#   CHOCO_DMG_URL      DMG to install (default: the latest GitHub release)
#   CHOCO_SHA_URL      checksum file for that DMG (default: "$CHOCO_DMG_URL.sha256")
#   CHOCO_INSTALL_DIR  where to put the app (default: /Applications)
set -euo pipefail

REPO="tarabakz25/choco"
APP_NAME="choco-browser.app"
APP_EXECUTABLE="choco-browser"
DMG_URL="${CHOCO_DMG_URL:-https://github.com/${REPO}/releases/latest/download/choco-browser.dmg}"
SHA_URL="${CHOCO_SHA_URL:-${DMG_URL}.sha256}"
INSTALL_DIR="${CHOCO_INSTALL_DIR:-/Applications}"

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "choco-browser is for macOS only."
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] \
  || fail "This build supports Apple Silicon only. Intel Macs are not supported."

macos="$(sw_vers -productVersion)"
[ "$(printf '%s\n' 15.4 "$macos" | sort -V | head -n 1)" = "15.4" ] \
  || fail "macOS 15.4 or later is required (this Mac runs $macos)."

if pgrep -x "$APP_EXECUTABLE" >/dev/null 2>&1; then
  fail "choco-browser is running. Quit it and run this again."
fi

tmp="$(mktemp -d)"
mnt="$tmp/mnt"
attached=""
cleanup() {
  if [ -n "$attached" ]; then hdiutil detach "$mnt" -quiet -force >/dev/null 2>&1 || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

dmg="$tmp/choco-browser.dmg"

info "Downloading the latest choco-browser"
curl -fL --progress-bar "$DMG_URL" -o "$dmg" \
  || fail "Could not download $DMG_URL (is there a published release yet?)"

info "Verifying SHA-256"
expected="$(curl -fsSL "$SHA_URL" | awk '{print $1; exit}')" \
  || fail "Could not fetch the checksum from $SHA_URL"
actual="$(shasum -a 256 "$dmg" | awk '{print $1}')"
[ -n "$expected" ] && [ "$expected" = "$actual" ] \
  || fail "Checksum mismatch (expected ${expected:-none}, got $actual). Nothing was installed."

info "Installing to $INSTALL_DIR"
mkdir -p "$mnt"
hdiutil attach "$dmg" -nobrowse -readonly -noautoopen -mountpoint "$mnt" -quiet >/dev/null
attached=1
[ -d "$mnt/$APP_NAME" ] || fail "$APP_NAME was not found in the DMG."

sudo_cmd=""
if [ -d "$INSTALL_DIR" ] && [ ! -w "$INSTALL_DIR" ]; then
  info "Administrator access is needed to write to $INSTALL_DIR"
  sudo_cmd="sudo"
fi
$sudo_cmd mkdir -p "$INSTALL_DIR"

staged="$INSTALL_DIR/.$APP_NAME.installing"
$sudo_cmd rm -rf "$staged"
$sudo_cmd ditto "$mnt/$APP_NAME" "$staged"
$sudo_cmd xattr -dr com.apple.quarantine "$staged" >/dev/null 2>&1 || true
$sudo_cmd rm -rf "${INSTALL_DIR:?}/$APP_NAME"
$sudo_cmd mv "$staged" "$INSTALL_DIR/$APP_NAME"

info "Installed $INSTALL_DIR/$APP_NAME"
printf '\nOpen it with:  open -a "%s"\n' "$INSTALL_DIR/$APP_NAME"
