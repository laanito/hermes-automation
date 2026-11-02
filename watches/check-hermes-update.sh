#!/usr/bin/env bash
# Alert when hermes-agent or the Talk bridge checkout is behind origin/main.
# Never applies updates. Silent if current, or if we already nagged this
# remote tip within 7 days. Do not trust `hermes update --check` commit
# counts on the installer shallow clone (they inflate into thousands).
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/bin:/bin"
export GIT_TERMINAL_PROMPT=0
FETCH_TIMEOUT="${HERMES_UPDATE_FETCH_TIMEOUT:-40}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT"
HERMES_SRC="${HERMES_SRC:-${HOME}/.hermes/hermes-agent}"
BRIDGE_SRC="${BRIDGE_SRC:-${BASE}/bridge}"
STATE="${HERMES_UPDATE_STATE:-${BASE}/data/hermes-update.state}"
NAG_SECS=$((7 * 24 * 3600))
now="$(date +%s)"
fail=0
notes=()

load_state() {
  last_hermes_remote=""
  last_bridge_remote=""
  last_alerted_at=0
  if [[ -f "$STATE" ]]; then
    last_hermes_remote="$(sed -n 's/^hermes_remote=//p' "$STATE" | tail -1)"
    last_bridge_remote="$(sed -n 's/^bridge_remote=//p' "$STATE" | tail -1)"
    last_alerted_at="$(sed -n 's/^alerted_at=//p' "$STATE" | tail -1)"
    last_alerted_at="${last_alerted_at:-0}"
  fi
}

save_state() {
  mkdir -p "$(dirname "$STATE")"
  umask 077
  cat >"$STATE" <<EOF
hermes_remote=${1}
bridge_remote=${2}
alerted_at=${3}
EOF
}

short() {
  local s="${1:-}"
  printf '%s' "${s:0:12}"
}

fetch_tips() {
  # Sets: ${prefix}_ok ${prefix}_local ${prefix}_remote ${prefix}_err
  local prefix="$1" dir="$2"
  local ok=0 local_sha="" remote_sha="" err=""
  if [[ ! -d "${dir}/.git" ]]; then
    err="not a git checkout: ${dir}"
  elif ! timeout "$FETCH_TIMEOUT" git -C "$dir" fetch --quiet --depth 1 origin main 2>/tmp/hermes-update-fetch.err; then
    err="git fetch failed: ${dir}: $(tr '\n' ' ' </tmp/hermes-update-fetch.err | head -c 240)"
  else
    local_sha="$(git -C "$dir" rev-parse HEAD)"
    remote_sha="$(git -C "$dir" rev-parse origin/main)"
    ok=1
  fi
  rm -f /tmp/hermes-update-fetch.err
  printf -v "${prefix}_ok" '%s' "$ok"
  printf -v "${prefix}_local" '%s' "$local_sha"
  printf -v "${prefix}_remote" '%s' "$remote_sha"
  printf -v "${prefix}_err" '%s' "$err"
}

dirty_note() {
  local dir="$1" label="$2"
  local porcelain
  porcelain="$(git -C "$dir" status --porcelain 2>/dev/null || true)"
  if [[ -n "$porcelain" ]]; then
    notes+=("NOTE: ${label} working tree dirty (stash/re-apply on update):")
    while IFS= read -r line; do
      [[ -n "$line" ]] && notes+=("  ${line}")
    done <<<"$porcelain"
  fi
}

fetch_tips hermes "$HERMES_SRC"
fetch_tips bridge "$BRIDGE_SRC"

# GitHub fetch/auth failures stay off Talk until fetch works again
# (expired token). Other check failures still alert.
if [[ "$hermes_ok" != 1 ]]; then
  if [[ "$hermes_err" == git\ fetch\ failed:* ]]; then
    :
  else
    echo "ALERT: hermes-agent check failed: ${hermes_err}"
    fail=1
  fi
fi
if [[ "$bridge_ok" != 1 ]]; then
  if [[ "$bridge_err" == git\ fetch\ failed:* ]]; then
    :
  else
    echo "ALERT: talk-bridge check failed: ${bridge_err}"
    fail=1
  fi
fi

hermes_behind=0
bridge_behind=0
if [[ "$hermes_ok" == 1 && "$hermes_local" != "$hermes_remote" ]]; then
  hermes_behind=1
fi
if [[ "$bridge_ok" == 1 && "$bridge_local" != "$bridge_remote" ]]; then
  bridge_behind=1
fi

if [[ "$hermes_behind" -eq 0 && "$bridge_behind" -eq 0 && "$fail" -eq 0 ]]; then
  save_state "${hermes_remote:-current}" "${bridge_remote:-current}" "$now"
  exit 0
fi

if [[ "$hermes_behind" -eq 1 || "$bridge_behind" -eq 1 ]]; then
  load_state
  same_tips=0
  if [[ "$hermes_behind" -eq 1 || "$bridge_behind" -eq 1 ]]; then
    if [[ "${hermes_remote:-}" == "$last_hermes_remote" && "${bridge_remote:-}" == "$last_bridge_remote" ]]; then
      same_tips=1
    fi
  fi
  age=$((now - last_alerted_at))
  if [[ "$same_tips" -eq 1 && "$last_alerted_at" -gt 0 && "$age" -lt "$NAG_SECS" ]]; then
    # Already told Talk about this pair of remote tips.
    exit 0
  fi

  echo "ALERT: Hermes updates available (alert only — do not auto-apply)."
  if [[ "$hermes_behind" -eq 1 ]]; then
    ver="$(hermes --version 2>/dev/null | head -1 || true)"
    echo "ALERT: hermes-agent local=$(short "$hermes_local") origin/main=$(short "$hermes_remote")"
    [[ -n "$ver" ]] && echo "$ver"
  fi
  if [[ "$bridge_behind" -eq 1 ]]; then
    echo "ALERT: talk-bridge local=$(short "$bridge_local") origin/main=$(short "$bridge_remote")"
  fi
  dirty_note "$HERMES_SRC" "hermes-agent"
  dirty_note "$BRIDGE_SRC" "talk-bridge"
  if [[ ${#notes[@]} -gt 0 ]]; then
    printf '%s\n' "${notes[@]}"
  fi
  echo "Apply from SSH when ready: hermes update --plan && hermes update --backup"
  echo "Then: systemctl --user restart nextcloud-talk-hermes-bridge nextcloud-talk-hermes-bridge-grok-chat"
  echo "See overlay PLAN.md (Hermes updates: alert only)"
  save_state "${hermes_remote:-}" "${bridge_remote:-}" "$now"
  fail=1
fi

exit "$fail"
