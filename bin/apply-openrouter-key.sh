#!/usr/bin/env bash
# Sync OPENROUTER_API_KEY from secrets/openrouter.env into automation profile + bridge env.
set -euo pipefail
SRC=/srv/praderas/automation-hermes/secrets/openrouter.env
set -a
# shellcheck disable=SC1090
source "$SRC"
set +a
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "OPENROUTER_API_KEY empty in $SRC — paste key first" >&2
  exit 2
fi

apply_to() {
  local file="$1"
  touch "$file"; chmod 600 "$file"
  python3 - "$file" <<'PY'
import os, sys
from pathlib import Path
p = Path(sys.argv[1])
key = os.environ["OPENROUTER_API_KEY"]
lines = p.read_text().splitlines() if p.exists() else []
out, found = [], False
for line in lines:
    if line.startswith("OPENROUTER_API_KEY="):
        out.append("OPENROUTER_API_KEY=" + key); found = True
    else:
        out.append(line)
if not found:
    out.append("OPENROUTER_API_KEY=" + key)
p.write_text("\n".join(out) + "\n")
print(f"updated {p} (key length {len(key)})")
PY
}

apply_to "$HOME/.hermes/profiles/automation/.env"
apply_to /srv/praderas/automation-hermes/.env
[[ -f /srv/praderas/automation-hermes/hermes-home/.env ]] && apply_to /srv/praderas/automation-hermes/hermes-home/.env || true

systemctl --user restart nextcloud-talk-hermes-bridge.service
systemctl --user is-active nextcloud-talk-hermes-bridge.service
echo "done"
