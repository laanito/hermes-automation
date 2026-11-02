#!/usr/bin/env bash
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/bin:/bin:${PATH}"
export HERMES_HOME="${HERMES_HOME:-$HOME/.hermes/profiles/automation}"
export TZ=Europe/Madrid
# Ensure DonSeTch path for WSP
if [[ -z "${DONSETCH_BIN:-}" && -x "${HOME}/.local/opt/donsetch/donsetch" ]]; then
  export DONSETCH_BIN="${HOME}/.local/opt/donsetch/donsetch"
fi
if [[ -f "$HERMES_HOME/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$HERMES_HOME/.env"
  set +a
fi

BASE=/srv/praderas/automation-hermes
PROMPT_FILE="${DIGEST_PROMPT:-$BASE/prompts/web-digest.md}"
CONTEXT_SCRIPT="${DIGEST_CONTEXT_SCRIPT:-$BASE/bin/digest-local-context.sh}"
LOG="$BASE/logs/web-digest.log"
mkdir -p "$(dirname "$LOG")"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "missing prompt $PROMPT_FILE" >&2
  exit 2
fi

LOCAL_CTX=""
if [[ -x "$CONTEXT_SCRIPT" ]]; then
  LOCAL_CTX="$("$CONTEXT_SCRIPT" 2>&1 || echo "(local context script failed)")"
else
  LOCAL_CTX="(no local context script)"
fi

TASK="$(printf '%s\n\n---\nSystem date (host): %s\n\n%s\n\n---\n%s\n' \
  "$(cat "$PROMPT_FILE")" \
  "$(date -R)" \
  "$LOCAL_CTX" \
  "Produce the briefing now. Use tools for web only; for Hoy/Casa use Local context above.")"

{
  echo "==== $(date -Iseconds) start ===="
  if /srv/praderas/automation-hermes/bin/automation-run.sh \
      --deliver --result-only --actor "web-digest" --max-turns 35 \
      "$TASK"; then
    echo "ok"
  else
    rc=$?
    echo "automation-run failed rc=$rc"
    "$BASE/bin/talk-deliver.sh" --actor "web-digest" "[web-digest] failed rc=$rc — check $LOG" || true
    exit "$rc"
  fi
} >>"$LOG" 2>&1
