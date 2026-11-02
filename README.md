# praderas-automation-hermes

Host overlay for **Automation Hermes** on `praderas-new` (`/srv/praderas/automation-hermes`).

This is **not** a fork of [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent). CLI updates stay `hermes update --channel main`. Talk bridge vendor checkout stays [robertlmann02/nextcloud-talk-hermes-bridge](https://github.com/robertlmann02/nextcloud-talk-hermes-bridge) under `bridge/` (gitignored).

Operator runbook on Main Hermes: skill `praderas-automation-hermes`.

## What is tracked

| Path | Role |
|------|------|
| `bin/` | watches runner, Talk deliver, digest, blog-deploy, key apply scripts |
| `watches/` | health + Hermes SHA nag (alert only) |
| `local-patches/` | standing CLI patch: email markdown→plain. `toolsets-*.patch` are **obsolete** — do not apply |
| `systemd/` | Talk bridge user units (gateway unit is rewritten by `hermes update`) |
| `prompts/` | web-digest prompt |
| `PLAN.md` | P0–P5 |
| `env.example` | key names only |
| `crontab.example` | user crontab block |

## Never commit

`.env`, `grok-chat.env`, `secrets/`, `logs/`, `data/`, `hermes-home/`, `bridge/`.

## Hermes CLI standing patch

After every `hermes update --channel main --keep-stash`:

```bash
git -C ~/.hermes/hermes-agent apply /srv/praderas/automation-hermes/local-patches/email-adapter-current.patch
```

Refresh that file from a live `git diff` when the hunk changes.

## Remote

Private GitHub: `laanito/praderas-automation-hermes` (deploy key on the host).
