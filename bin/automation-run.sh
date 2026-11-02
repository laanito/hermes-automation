#!/usr/bin/env bash
# Run a one-shot Automation Hermes task on this host (profile automation).
# Usage:
#   automation-run.sh "task"
#   automation-run.sh --deliver "task"              # post task+result to Talk
#   automation-run.sh --deliver --result-only "task"  # post result only
#   automation-run.sh --max-turns N "task"
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.local/bin:${HOME}/.hermes/bin:/usr/bin:/bin:${PATH}"
export HERMES_HOME="${HERMES_HOME:-$HOME/.hermes/profiles/automation}"

if [[ -f "$HERMES_HOME/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$HERMES_HOME/.env"
  set +a
fi
if [[ -z "${DONSETCH_BIN:-}" && -x "$HOME/.local/opt/donsetch/donsetch" ]]; then
  export DONSETCH_BIN="$HOME/.local/opt/donsetch/donsetch"
fi

DELIVER=0
RESULT_ONLY=0
MAX_TURNS=""
ACTOR="Main delegate"
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --deliver) DELIVER=1; shift ;;
    --result-only) RESULT_ONLY=1; shift ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    -h|--help)
      echo "usage: automation-run.sh [--deliver] [--result-only] [--actor NAME] [--max-turns N] \"task\""
      exit 0
      ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
if [[ ${#ARGS[@]} -eq 0 ]]; then
  echo "usage: automation-run.sh [--deliver] \"task\"" >&2
  exit 2
fi
TASK="${ARGS[*]}"

OUT="$(mktemp)"
ERR="$(mktemp)"
trap "rm -f \"$OUT\" \"$ERR\"" EXIT

set +e
if [[ -n "$MAX_TURNS" ]]; then
  hermes --profile automation chat -q "$TASK" --quiet --max-turns "$MAX_TURNS" >"$OUT" 2>"$ERR"
else
  hermes --profile automation -z "$TASK" >"$OUT" 2>"$ERR"
fi
rc=$?
set -e

RESULT="$(grep -v "^session_id:" "$OUT" | sed "/^$/d" || true)"
if [[ -z "$RESULT" ]]; then
  RESULT="$(cat "$OUT")"
fi
if [[ -z "$RESULT" && -s "$ERR" ]]; then
  RESULT="(no stdout; hermes rc=$rc)
$(tail -c 2000 "$ERR")"
fi

printf "%s\n" "$RESULT"

if [[ "$DELIVER" -eq 1 ]]; then
  if [[ "$RESULT_ONLY" -eq 1 ]]; then
    MSG="$(printf "%s" "$RESULT" | head -c 3500)"
  else
    MSG="$(printf "Main→Automation task:\n%s\n\nResult (rc=%s):\n%s" "$TASK" "$rc" "$RESULT" | head -c 3500)"
  fi
  "$ROOT/bin/talk-deliver.sh" --actor "$ACTOR" "$MSG" || true
fi
exit "$rc"
