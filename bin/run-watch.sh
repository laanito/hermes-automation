#!/usr/bin/env bash
# run-watch.sh NAME -- command...
# If command exits non-zero OR prints ALERT lines, deliver to Talk. Else silent.
set -euo pipefail
BASE=/srv/praderas/automation-hermes
DELIVER="$BASE/bin/talk-deliver.sh"
NAME="${1:-watch}"
shift || true
if [[ "${1:-}" == "--" ]]; then shift; fi
if [[ $# -lt 1 ]]; then
  echo "usage: run-watch.sh NAME -- command..." >&2
  exit 2
fi

out="$(mktemp)"
trap "rm -f \"$out\"" EXIT
set +e
"$@" >"$out" 2>&1
rc=$?
set -e

body="$(cat "$out")"
if [[ $rc -eq 0 && -z "$(echo "$body" | grep -E "^ALERT:" || true)" ]]; then
  exit 0
fi

# truncate for Talk
summary="$(echo "$body" | head -c 3500)"
msg="[$NAME] rc=$rc
$summary"
"$DELIVER" --actor "watch:$NAME" "$msg" || true
exit 0
