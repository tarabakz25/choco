#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
python3 scripts/fixture-server.py --port 8765 > .build/fixture-server.log 2>&1 &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true' EXIT
ready=0
for attempt in {1..40}; do
    if ! kill -0 "$fixture_pid" 2>/dev/null; then cat .build/fixture-server.log >&2; exit 1; fi
    if curl --fail --silent http://127.0.0.1:8765/ > /dev/null; then ready=1; break; fi
    sleep 0.1
done
if [ "$ready" != 1 ]; then echo 'Fixture server did not start' >&2; exit 1; fi
xcodebuild -project choco-browser.xcodeproj -scheme choco-browser -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode \
    -clonedSourcePackagesDirPath .build/SourcePackages test "$@"
