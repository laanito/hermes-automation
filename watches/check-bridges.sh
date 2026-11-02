#!/usr/bin/env bash
# Cron-safe: user systemd needs XDG_RUNTIME_DIR; always require HTTP health.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then set -a; source "$ROOT/.env"; set +a; fi
uid="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
if [[ -S "$XDG_RUNTIME_DIR/bus" ]]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
fi

fail=0
for u in nextcloud-talk-hermes-bridge.service nextcloud-talk-hermes-bridge-grok-chat.service; do
  if command -v systemctl >/dev/null && [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    if ! systemctl --user is-active --quiet "$u" 2>/dev/null; then
      echo "ALERT: systemd unit not active: $u"
      fail=1
    fi
  fi
done
for url in http://127.0.0.1:8788/health http://127.0.0.1:8789/health; do
  if ! curl -sf -m 5 "$url" >/dev/null; then
    echo "ALERT: health failed: $url"
    fail=1
  fi
done
base="${NEXTCLOUD_URL:-}"
base="${base%/}"
if [[ -n "$base" ]]; then
  for path in /hermes-talk/health /hermes-grok-chat/health; do
    url="$base$path"
    if ! curl -sf -m 10 "$url" >/dev/null; then
      echo "ALERT: public health failed: $url"
      fail=1
    fi
  done
fi
if [[ $fail -ne 0 ]]; then exit 1; fi
exit 0
