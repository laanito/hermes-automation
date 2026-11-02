#!/usr/bin/env bash
# On praderas-new: after mailbox exists, set EMAIL_PASSWORD and start email gateway.
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
PROF_ENV="${HOME}/.hermes/profiles/email/.env"
SECRETS="/srv/praderas/automation-hermes/secrets/email-hermes.env"

if [[ ! -f "$PROF_ENV" ]]; then
  echo "missing $PROF_ENV — create email profile first" >&2
  exit 2
fi

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  PASS="$1"
elif [[ -f "$SECRETS" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$SECRETS"; set +a
  PASS="${EMAIL_PASSWORD:-}"
else
  echo "usage: $0 <mailbox-password>" >&2
  echo "or put EMAIL_PASSWORD=... in $SECRETS" >&2
  exit 2
fi

if [[ -z "$PASS" || "$PASS" == "REPLACE_ME" ]]; then
  echo "empty password" >&2
  exit 2
fi

python3 - "$PROF_ENV" "$PASS" <<'PY'
from pathlib import Path
import sys
path, pw = Path(sys.argv[1]), sys.argv[2]
lines=[]
found=False
for line in path.read_text().splitlines():
    if line.startswith("EMAIL_PASSWORD="):
        lines.append("EMAIL_PASSWORD="+pw); found=True
    else:
        lines.append(line)
if not found:
    lines.append("EMAIL_PASSWORD="+pw)
path.write_text("\n".join(lines)+"\n")
path.chmod(0o600)
print("password set in", path)
PY

# secrets copy (mode 600) without echoing
install -m 600 /dev/null "$SECRETS" 2>/dev/null || touch "$SECRETS"
python3 - "$SECRETS" "$PASS" <<'PY'
from pathlib import Path
import sys
p, pw = Path(sys.argv[1]), sys.argv[2]
p.write_text(
  "EMAIL_ADDRESS=hermes@praderas.org\n"
  f"EMAIL_PASSWORD={pw}\n"
  "EMAIL_ALLOWED_USERS=lamigo@praderas.org,lamigo@praderas.es\n"
)
p.chmod(0o600)
print("secrets file updated", p)
PY

# Quick IMAP/SMTP probe
export HERMES_HOME="${HOME}/.hermes/profiles/email"
set -a; source "$PROF_ENV"; set +a
python3 <<'PY'
import imaplib, smtplib, os, ssl
addr=os.environ["EMAIL_ADDRESS"]
pw=os.environ["EMAIL_PASSWORD"]
imap_host=os.environ["EMAIL_IMAP_HOST"]
smtp_host=os.environ["EMAIL_SMTP_HOST"]
print("IMAP…", end=" ")
M=imaplib.IMAP4_SSL(imap_host, 993)
M.login(addr, pw)
typ, _=M.select("INBOX")
print(typ, "ok")
M.logout()
print("SMTP…", end=" ")
s=smtplib.SMTP(smtp_host, 587, timeout=30)
s.ehlo(); s.starttls(context=ssl.create_default_context()); s.ehlo()
s.login(addr, pw)
print("ok")
s.quit()
PY

# Install/restart gateway for email profile only
hermes --profile email gateway install 2>&1 || true
hermes --profile email gateway restart 2>&1 || hermes --profile email gateway start 2>&1 || true
sleep 2
hermes --profile email gateway status 2>&1 | head -40
echo "Done. Only EMAIL_ALLOWED_USERS can talk; replies go in-thread to sender (Luis)."
