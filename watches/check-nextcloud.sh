#!/usr/bin/env bash
set -euo pipefail
# Local status via nginx or loopback NC
code="$(curl -sS -o /tmp/nc-status.json -w "%{http_code}" -m 10 https://nube.praderas.org/status.php || echo 000)"
if [[ "$code" != "200" ]]; then
  echo "ALERT: Nextcloud status.php HTTP $code"
  cat /tmp/nc-status.json 2>/dev/null || true
  exit 1
fi
if ! python3 - <<'PY'
import json
from pathlib import Path
p=Path("/tmp/nc-status.json")
try:
    d=json.loads(p.read_text())
except Exception as e:
    print("ALERT: status.php not JSON", e)
    raise SystemExit(1)
if not d.get("installed"):
    print("ALERT: Nextcloud reports installed=false")
    raise SystemExit(1)
if d.get("maintenance"):
    print("ALERT: Nextcloud maintenance mode is on")
    raise SystemExit(1)
raise SystemExit(0)
PY
then
  exit 1
fi
# compose stack
if ! docker ps --format "{{.Names}}" | grep -qx nextcloud; then
  # try compose project name patterns
  if ! docker ps --format "{{.Names}}" | grep -qi nextcloud; then
    echo "ALERT: no nextcloud container running"
    docker ps --format "{{.Names}} {{.Status}}" | head -20
    exit 1
  fi
fi
exit 0
