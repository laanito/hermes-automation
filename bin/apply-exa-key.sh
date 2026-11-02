#!/usr/bin/env bash
# Sync EXA_API_KEY from secrets/exa.env into Hermes profile + bridge env (no value printed).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/secrets/exa.env"
if [[ ! -f "$SRC" ]]; then
  echo "missing $SRC" >&2
  exit 2
fi
# shellcheck disable=SC1090
set -a
source "$SRC"
set +a
if [[ -z "${EXA_API_KEY:-}" ]]; then
  echo "EXA_API_KEY is empty in $SRC — paste the key there first" >&2
  exit 2
fi

apply_to() {
  local file="$1"
  touch "$file"
  chmod 600 "$file"
  if grep -q "^EXA_API_KEY=" "$file" 2>/dev/null; then
    # replace line in place without echoing value
    python3 - "$file" <<'PY'
import os, sys
from pathlib import Path
p = Path(sys.argv[1])
key = os.environ["EXA_API_KEY"]
lines = p.read_text().splitlines()
out = []
found = False
for line in lines:
    if line.startswith("EXA_API_KEY="):
        out.append("EXA_API_KEY=" + key)
        found = True
    else:
        out.append(line)
if not found:
    out.append("EXA_API_KEY=" + key)
p.write_text("\n".join(out) + "\n")
PY
  else
    printf "\nEXA_API_KEY=%s\n" "$EXA_API_KEY" >>"$file"
  fi
  echo "updated $file (key length ${#EXA_API_KEY})"
}

apply_to "$HOME/.hermes/profiles/automation/.env"
apply_to "$ROOT/.env"
# optional legacy docker-era home
if [[ -f "$ROOT/hermes-home/.env" ]]; then
  apply_to "$ROOT/hermes-home/.env"
fi

# bridge picks EnvironmentFile on restart
systemctl --user restart nextcloud-talk-hermes-bridge.service
# grok-chat may also want web; optional — only if its env has EXA
if grep -q EXA "$ROOT/grok-chat.env" 2>/dev/null; then
  apply_to "$ROOT/grok-chat.env"
  systemctl --user restart nextcloud-talk-hermes-bridge-grok-chat.service || true
fi
systemctl --user is-active nextcloud-talk-hermes-bridge.service
echo "done — hermes config show should mask Exa as set"
