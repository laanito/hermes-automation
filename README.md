# hermes-automation

Host overlay for a 24×7 **Automation Hermes**: Nextcloud Talk bridges, health watches, digests, and standing CLI patches.

This is **not** a fork of [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent). CLI updates stay `hermes update --channel main`. Talk I/O is [robertlmann02/nextcloud-talk-hermes-bridge](https://github.com/robertlmann02/nextcloud-talk-hermes-bridge) as git submodule `bridge/` (pin = the host checkout). `bin/talk-deliver.sh` is the outbound `/deliver` helper. Do not vendor `.venv`.

Scripts resolve the overlay root from their own location (`$(dirname)/..`). Copy this tree anywhere; point systemd `EnvironmentFile` and crontab at that root. Do not commit host paths, room tokens, or mailbox names.

## What is tracked

| Path | Role |
|------|------|
| `bin/` | watches runner, Talk deliver, digest, blog-deploy, key apply |
| `bridge/` | Talk bridge (submodule; Python package `nextcloud_talk_hermes_bridge`) |
| `watches/` | health + Hermes SHA nag (alert only, never auto-update) |
| `local-patches/` | standing CLI patch: email markdown→plain. `toolsets-*.patch` are obsolete — do not apply |
| `systemd/` | Talk bridge **unit templates** (`@OVERLAY_ROOT@`) — install into `~/.config/systemd/user/` after substituting |
| `prompts/` | web-digest prompt |
| `PLAN.md` | capability roadmap |
| `env.example` | key names only |
| `crontab.example` | user crontab block |

## Never commit

`.env`, `grok-chat.env`, `secrets/`, `logs/`, `data/`, `hermes-home/`, `bridge/.venv`.

## Hermes CLI standing patch

After every `hermes update --channel main --keep-stash`:

```bash
git -C ~/.hermes/hermes-agent apply ./local-patches/email-adapter-current.patch
```

(from the overlay root). Refresh that file from a live `git diff` when the hunk changes.
