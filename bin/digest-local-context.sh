#!/usr/bin/env bash
# Collect local context for the morning digest (no secrets).
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/bin:/bin:${PATH}"
export HERMES_HOME="${HERMES_HOME:-$HOME/.hermes/profiles/automation}"
export TZ=Europe/Madrid

if [[ -f "$HERMES_HOME/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$HERMES_HOME/.env"
  set +a
fi
if [[ -f "$HERMES_HOME/nextcloud.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$HERMES_HOME/nextcloud.env"
  set +a
fi

TODAY=$(date +%F)
echo "## Local context (host facts — do not invent beyond this)"
echo "Date/time: $(date -R)"
echo

echo "### Agenda today ($TODAY)"
if command -v nc-hermes >/dev/null 2>&1; then
  timeout 60 nc-hermes calendar list --from "$TODAY" --to "$TODAY" 2>/dev/null \
    || echo '{"status":"error","message":"calendar list failed"}'
else
  echo "nc-hermes missing"
fi
echo

echo "### Open tasks (Nextcloud)"
if command -v nc-hermes >/dev/null 2>&1; then
  RAW=$(timeout 45 nc-hermes tasks list 2>/dev/null || true)
  if [[ -z "${RAW// }" ]]; then
    echo '{"status":"error","message":"tasks list empty/failed"}'
  else
    printf '%s' "$RAW" | python3 -c '
import json,sys
raw=sys.stdin.read()
try:
    d=json.loads(raw)
except Exception as e:
    print(json.dumps({"status":"error","message":str(e),"raw_head":raw[:200]}, ensure_ascii=False))
    raise SystemExit(0)
items=d.get("data") or []
open_=[]
for t in items:
    st=(t.get("status") or "").upper()
    if st in ("COMPLETED","CANCELLED"):
        continue
    open_.append({k:t.get(k) for k in ("uid","summary","due","status","calendar") if t.get(k) is not None})
print(json.dumps({"status":"success","count":len(open_),"data":open_[:25]}, ensure_ascii=False))
'
  fi
else
  echo "nc-hermes missing"
fi
echo

echo "### Deck snapshot (Personal)"
if command -v nc-deck >/dev/null 2>&1; then
  timeout 20 nc-deck browse --board Personal 2>/dev/null \
    || echo '{"status":"error","message":"deck browse failed"}'
else
  echo "nc-deck missing"
fi
echo

echo "### Box health"
if command -v apt-get >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  # do NOT apt-get update here (slow/noisy); count cached upgradable list only
  COUNT=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l | tr -d " ")
  echo "apt_upgradable_packages_cached: ${COUNT}"
else
  echo "apt_upgradable_packages_cached: unknown"
fi
df -h / 2>/dev/null | awk "NR==1 || /\\/\$/"
if command -v docker >/dev/null 2>&1; then
  echo "docker_system_df:"
  timeout 10 docker system df 2>/dev/null | head -6 || true
fi
echo

echo "### Blog"
if command -v blog-deploy >/dev/null 2>&1; then
  timeout 30 blog-deploy status 2>/dev/null || true
fi
