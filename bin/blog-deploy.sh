#!/usr/bin/env bash
# Deploy the Pico blog: ff-only git pull on the live tree + HTTP checks.
# Safe ops only — no push, no force, no reset, no config edits.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"; set +a
fi
PICO="${BLOG_PICO:-}"
BRANCH="${BLOG_BRANCH:-main}"
REMOTE="${BLOG_REMOTE:-origin}"
SITE="${BLOG_URL:-}"
if [[ -z "$PICO" || -z "$SITE" ]]; then
  echo "blog-deploy: set BLOG_PICO and BLOG_URL in overlay .env" >&2
  exit 2
fi

# GitHub HTTP/2: unauthenticated POST /git-upload-pack returns 401.
# HTTP/1.1 works for public clone/fetch without credentials.
git_http() { git -c http.version=HTTP/1.1 "$@"; }

cmd="${1:-deploy}"
shift || true

usage() {
  cat <<EOF
Usage:
  blog-deploy status
  blog-deploy deploy [optional/blog/path ...]
  blog-deploy check [optional/blog/path ...]

Only ff-only pull of ${REMOTE}/${BRANCH} into ${PICO}.
Never push, force, reset, or edit content.
EOF
}

http_code() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" -L --connect-timeout 10 "$url" 2>/dev/null || echo 000
}

case "$cmd" in
  -h|--help|help)
    usage
    exit 0
    ;;
  status)
    cd "$PICO"
    python3 - <<PY
import json, subprocess
from pathlib import Path
pico = Path("$PICO")
def sh(*a):
    return subprocess.check_output(a, cwd=pico, text=True).strip()
branch = sh("git", "rev-parse", "--abbrev-ref", "HEAD")
head = sh("git", "log", "-1", "--format=%h %ci %s")
try:
    ab = sh("git", "rev-list", "--left-right", "--count", f"HEAD...$REMOTE/$BRANCH")
except Exception:
    ab = "? ?"
dirty = len([l for l in subprocess.check_output(["git","status","--porcelain"], cwd=pico, text=True).splitlines() if l.strip()])
print(json.dumps({
  "status": "success",
  "data": {
    "path": str(pico),
    "branch": branch,
    "head": head,
    "ahead_behind_vs_remote": ab,
    "dirty_files": dirty,
  }
}, ensure_ascii=False))
PY
    ;;
  deploy)
    cd "$PICO"
    before=$(git rev-parse --short HEAD)
    git_http fetch --quiet "$REMOTE" "$BRANCH"
    local_sha=$(git rev-parse HEAD)
    remote_sha=$(git rev-parse "$REMOTE/$BRANCH")
    if [[ "$local_sha" != "$remote_sha" ]]; then
      if ! git merge-base --is-ancestor HEAD "$REMOTE/$BRANCH"; then
        python3 -c 'import json; print(json.dumps({"status":"error","message":"refusing non-ff deploy: local is not ancestor of remote"}))'
        exit 1
      fi
      git_http pull --ff-only --quiet "$REMOTE" "$BRANCH"
    fi
    after=$(git rev-parse --short HEAD)
    subject=$(git log -1 --format="%s")
    # build checks JSON via python
    paths=("$@")
    python3 - "$SITE" "$before" "$after" "$subject" "$PICO" "${paths[@]}" <<'PY'
import json, sys, subprocess
site, before, after, subject, pico = sys.argv[1:6]
paths = sys.argv[6:]

def code(url):
    try:
        out = subprocess.check_output(
            ["curl","-sS","-o","/dev/null","-w","%{http_code}","-L","--connect-timeout","10", url],
            text=True,
        ).strip()
        return out
    except Exception:
        return "000"

checks = [{"url": site.rstrip("/") + "/", "code": code(site.rstrip("/") + "/")}]
for rel in paths:
    rel = rel.lstrip("/")
    url = site.rstrip("/") + "/" + rel
    checks.append({"url": url, "code": code(url)})

print(json.dumps({
  "status": "success",
  "data": {
    "deployed": True,
    "changed": before != after,
    "before": before,
    "after": after,
    "subject": subject,
    "path": pico,
    "checks": checks,
  }
}, ensure_ascii=False))
PY
    ;;
  check)
    paths=("$@")
    python3 - "$SITE" "${paths[@]}" <<'PY'
import json, sys, subprocess
site = sys.argv[1]
paths = sys.argv[2:] or [""]

def code(url):
    try:
        return subprocess.check_output(
            ["curl","-sS","-o","/dev/null","-w","%{http_code}","-L","--connect-timeout","10", url],
            text=True,
        ).strip()
    except Exception as e:
        return "000"

checks = []
for rel in paths:
    rel = rel.lstrip("/")
    url = site.rstrip("/") + "/" + rel if rel else site.rstrip("/") + "/"
    checks.append({"url": url, "code": code(url)})
print(json.dumps({"status": "success", "data": {"checks": checks}}, ensure_ascii=False))
PY
    ;;
  *)
    python3 -c 'import json,sys; print(json.dumps({"status":"error","message":"unknown command: %s (status|deploy|check)"%sys.argv[1]}))' "$cmd"
    exit 2
    ;;
esac
