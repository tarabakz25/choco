#!/bin/bash
set -euo pipefail
app_path="${1:?Usage: scripts/relaunch-app.sh <path to .app>}"
bundle_id='org.ossarc.browser'
process_name='choco-browser'

is_running() { pgrep -qx "$process_name"; }

# 指定回数（0.1秒間隔）だけ終了を待つ。終了していれば 0 を返す
wait_for_exit() {
  for _ in $(seq "$1"); do
    is_running || return 0
    sleep 0.1
  done
  ! is_running
}

if is_running; then
  # まず正常終了を要求して状態を保存させる。応答がなくても AppleEvent の既定待機（約2分）にならないよう 5 秒で打ち切る
  osascript -e "tell application id \"$bundle_id\"" -e 'with timeout of 5 seconds' -e 'quit' -e 'end timeout' -e 'end tell' >/dev/null 2>&1 || true
  if ! wait_for_exit 100; then
    # 応答しない場合は TERM → KILL の順にエスカレートし、各段階で終了を確認する
    pkill -x "$process_name" || true
    if ! wait_for_exit 50; then
      pkill -KILL -x "$process_name" || true
      if ! wait_for_exit 50; then
        echo "Failed to stop running $process_name; not relaunching." >&2
        exit 1
      fi
    fi
  fi
fi

# 直前に終了したプロセスは LaunchServices にまだ残っている場合があり、open が -600 で失敗するため短く再試行する
for _ in $(seq 50); do
  open "$app_path" 2>/dev/null && exit 0
  sleep 0.1
done
open "$app_path"
