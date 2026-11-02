# Automation Hermes — capability roadmap

**Roles:** Main Hermes (operator laptop) · Automation Hermes (host CLI, profile `automation`) · Grok chat (profile `grok-chat`, conversational only)

**Locked architecture:** official host Hermes CLI + Docker *terminal backend* only; unmodified nextcloud-talk-hermes-bridge; AppAPI off.

**Rooms** (tokens in overlay `.env`, never in git):

| Room | Env | Use |
|------|-----|-----|
| Automation Hermes | `$TALK_ROOM_AUTOMATION` / `$NEXTCLOUD_TALK_HOME_ROOM` | Ops, NC content, digests, alerts |
| Grok chat | `$TALK_ROOM_GROK` | Conversation + web search only |

**Deliver:** `POST http://127.0.0.1:8788/deliver` with `Authorization: Bearer $TALK_DELIVER_SECRET` and JSON `{room_token, message, actor?}`. Helper: `bin/talk-deliver.sh`.

---

## P0 — Trust the channel (alerts) ✅

Script watches (no LLM log tailing). Silence on OK; post to Automation room on failure.

- [x] `bin/talk-deliver.sh`
- [x] Watches: bridges, NC status.php, disk
- [x] Cron install

## P1 — Nextcloud **content** (not instance admin) ✅

- [x] App password for content APIs only
- [x] [hermes-nextcloud](https://github.com/adnw-vinc/hermes-nextcloud) in automation profile
- [x] WebDAV, Notes, CalDAV, Tasks, contacts
- [x] Wrapper `nc-hermes`
- [x] `terminal.backend=local`

## P2 — Main → Automation delegation ✅

- [x] `bin/automation-run.sh` on the host
- [x] Laptop helper SSHes that script
- [x] Optional `--deliver` to Talk
- Main does **not** hold the NC app password

## P3 — Scheduled web research / digests ✅

- [x] `prompts/web-digest.md`
- [x] `bin/run-web-digest.sh` → `--deliver --result-only`
- [x] Weekdays 08:15 local tz via user crontab
- [x] `logs/web-digest.log`

## P4 — Deck ✅

- Deck REST; wrapper `nc-deck`
- Cards only — no board/stack delete by default
- Never on grok-chat

## P5 — Email digest (after mail cutover)

- Read-only IMAP with a dedicated secret
- Short digest → `/deliver`
- No full-mailbox LLM dumps

---

## Non-goals

- Automation as a full privileged “server self-management” Hermes
- Honcho on Automation (personal memory stays Main)
- Free-form cron from Talk until templates exist
- LLM continuous log monitoring
- Grok chat gaining ops/NC tools

## Safety

- YOLO off on Talk bridges
- Secrets in env files mode 600 only
- Watches: empty stdout + exit 0 = silent
- Deliver only to room tokens from env

## Secrets (ops)

- `secrets/*.env` → `bin/apply-*-key.sh` (sync into profile + bridge env). Never commit.

## Model

- Primary: `grok-4.6` (xAI)
- Fallback: OpenRouter (see `secrets/openrouter.env`)

## Blog deploy

- ff-only pull of the live Pico tree; HTTP checks
- Paths/URL from env (`BLOG_PICO`, `BLOG_URL`)
- Never push/force from Automation

## Email Q&A (not the automation door)

- Separate `email` profile / gateway
- Allowlist in profile `.env`; Talk remains the ops interface
