# Automation Hermes — capability roadmap

**Names:** Main Hermes (Mac) · Automation Hermes (praderas-new, profile `automation`) · Grok chat (profile `grok-chat`, conversational only)

**Locked architecture:** official host Hermes CLI + Docker *terminal backend* only; unmodified nextcloud-talk-hermes-bridge; AppAPI off; mail can stay on old box until DMS.

**Rooms**
| Room | Token | Use |
|------|-------|-----|
| Automation Hermes | `4tr8ku3n` | Ops, NC content, digests, alerts |
| Grok chat | `o6kof9p9` | Conversation + web search only |

**Deliver:** `POST http://127.0.0.1:8788/deliver` with `Authorization: Bearer $TALK_DELIVER_SECRET` and JSON `{room_token, message, actor?}`. Helper: `bin/talk-deliver.sh`.

---

## P0 — Trust the channel (alerts) ✅ done
Script watches (no LLM log tailing). Silence on OK; post to Automation room on failure.

- [x] Plan document
- [x] `bin/talk-deliver.sh`
- [x] Watches: bridges systemd, NC status.php, disk
- [x] Cron install
- [x] End-to-end test message

## P1 — Nextcloud **content** (not instance admin) ✅ done
- [x] App password (or dedicated user) for content APIs only
- [x] Install [hermes-nextcloud](https://github.com/adnw-vinc/hermes-nextcloud) into automation profile skills
- [x] Covers: WebDAV files, Notes API, CalDAV calendar, Tasks (VTODO), contacts
- [x] Widen Automation Talk toolsets: web,memory,session_search,clarify,skills,terminal,file; HERMES_SKILLS=nextcloud
- [x] Smoke: check auth, files list, calendar events list, tasks list
- [x] terminal.backend=local (skill is HTTPS-only; docker backend cannot see host skill/env)
- [x] App password name hermes-automation for user lamigo; secrets in profile nextcloud.env + secrets/nextcloud.env
- Wrapper: `nc-hermes` → nextcloud_api.py

## P2 — Main → Automation delegation ✅ done
- [x] Server: `/srv/praderas/automation-hermes/bin/automation-run.sh` (+ `~/.local/bin/automation-run`)
- [x] Mac Main: `~/.local/bin/automation-hermes` → `ssh praderas-new` → automation-run
- [x] Optional `--deliver` posts result to Automation Talk room via talk-deliver.sh
- [x] Main Hermes skill: `~/.hermes/skills/devops/automation-hermes-delegate/SKILL.md`
- [x] Smoke: Mac oneshot + deliver path
- Main does **not** hold NC app password

## P3 — Scheduled web research / digests ✅ done
- [x] Prompt: `prompts/web-digest.md` (ES, skim-friendly, web/Exa)
- [x] Runner: `bin/run-web-digest.sh` → `automation-run.sh --deliver` → room `4tr8ku3n`
- [x] Schedule: user crontab weekdays **08:15 Europe/Madrid**
- [x] Log: `logs/web-digest.log`; failure also Talk-alerts
- Edit topics in the prompt file; no free-form cron-from-Talk
- Optional later: hermes cron continuity if we want cross-day dedupe via job notepad

## P4 — Deck (Nextcloud Deck REST API) ✅ done
- Spec: https://deck.readthedocs.io/en/latest/API/
- Skill: `~/.hermes/profiles/automation/skills/productivity/deck`
- Wrapper: `nc-deck` (boards, browse, stacks, cards, create, update, move)
- Auth: same `nextcloud.env` app password; API base `/index.php/apps/deck/api/v1.0`
- Talk: `HERMES_SKILLS=nextcloud,deck`; allowlist `nc-deck *`
- Scope: read + card create/update/move; **no** board/stack/card delete by default
- Never on grok-chat

## P5 — Email digest (after DMS/MX on new box)
- Read-only IMAP or NC Mail path with dedicated secret
- Script or hermes cron → short digest → `/deliver`
- No full-mailbox LLM dumps by default

---

## Non-goals
- Automation as full privileged “server self-management” Hermes
- Honcho on Automation (personal memory stays Main)
- Free-form cron creation from Talk until templates exist
- LLM continuous log monitoring
- Grok chat gaining ops/NC content tools

## Safety
- YOLO off on Talk bridges
- Secrets in env files mode 600 only
- Watches: empty stdout + exit 0 = silent
- Deliver only to known room tokens

## Secrets (ops)
- Exa API key: edit `/srv/praderas/automation-hermes/secrets/exa.env` then run `bin/apply-exa-key.sh`
  (syncs into profile automation `.env` + bridge `.env`, restarts Talk bridge). Never commit.

## Model (Automation profile)
- Primary: `grok-4.6` via xAI (was grok-4.20-0309-non-reasoning; switched 2026-08-29 for sharper NC write adherence)
- Fallback: `nvidia/nemotron-3-super-120b-a12b:free` via OpenRouter
- OpenRouter key: `secrets/openrouter.env` → `bin/apply-openrouter-key.sh`

## Blog deploy (icing)
- Skill `praderasblog-deploy` + CLI `blog-deploy`
- `blog-deploy deploy` = ff-only pull on `/srv/praderas/pico` + HTTP checks
- Talk: HERMES_SKILLS includes praderasblog-deploy; allowlist blog-deploy*
- Never push/force from Automation

## Email Q&A (thin path, not automation door)
- Profile: `email` on praderas-new (`hermes --profile email gateway`)
- Address: `hermes@praderas.org` on **old MX** (correo); IMAP/SMTP there
- `EMAIL_ALLOWED_USERS=lamigo@praderas.org,lamigo@praderas.es` only
- Replies in-thread to Luis only; Talk remains sole automation interface
- Provision mailbox: on correo `sudo bash /tmp/provision-hermes-mailbox.sh`
- Apply: `/srv/praderas/automation-hermes/bin/apply-email-hermes.sh <password>`
- No DMS required
