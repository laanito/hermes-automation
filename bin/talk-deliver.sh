#!/usr/bin/env bash
# Post a message to a Nextcloud Talk room via the local hermes bridge /deliver endpoint.
# Usage:
#   talk-deliver.sh "message text"
#   talk-deliver.sh --room TOKEN "message"
#   echo "msg" | talk-deliver.sh
#   talk-deliver.sh --actor "watch-disk" "Disk above 90%"
set -euo pipefail

ENV_FILE="${TALK_DELIVER_ENV:-/srv/praderas/automation-hermes/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DELIVER_URL="${NEXTCLOUD_TALK_DELIVER_URL:-http://127.0.0.1:8788/deliver}"
ROOM="${NEXTCLOUD_TALK_HOME_ROOM:-}"
ACTOR="Automation watch"
SECRET="${TALK_DELIVER_SECRET:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --room) ROOM="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --url) DELIVER_URL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--room TOKEN] [--actor NAME] [message...]"
      exit 0
      ;;
    --) shift; break ;;
    *) break ;;
  esac
done

if [[ $# -gt 0 ]]; then
  MSG="$*"
else
  MSG="$(cat || true)"
fi

MSG="$(printf "%s" "$MSG" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//")"
if [[ -z "$MSG" ]]; then
  echo "talk-deliver: empty message" >&2
  exit 2
fi
if [[ -z "$SECRET" ]]; then
  echo "talk-deliver: TALK_DELIVER_SECRET missing" >&2
  exit 2
fi
if [[ -z "$ROOM" ]]; then
  echo "talk-deliver: room token missing (NEXTCLOUD_TALK_HOME_ROOM or --room)" >&2
  exit 2
fi

# JSON-escape via python
payload="$(MSG="$MSG" ROOM="$ROOM" ACTOR="$ACTOR" python3 - <<PY
import json, os
print(json.dumps({
  "room_token": os.environ["ROOM"],
  "message": os.environ["MSG"],
  "actor": os.environ["ACTOR"],
}))
PY
)"

code="$(curl -sS -o /tmp/talk-deliver-out.json -w "%{http_code}" \
  -X POST "$DELIVER_URL" \
  -H "Authorization: Bearer ${SECRET}" \
  -H "Content-Type: application/json" \
  -d "$payload" || true)"

if [[ "$code" != "200" ]]; then
  echo "talk-deliver: HTTP $code $(cat /tmp/talk-deliver-out.json 2>/dev/null || true)" >&2
  exit 1
fi
exit 0
