---
description: Set up CCF panelists interactively — pick providers from the catalog, add keys, validate, and enable panelists. Runs in your terminal (keys are never pasted into chat).
---

# /fusion-onboard — guided CCF setup

Onboarding collects **API keys**, so it must run in the user's terminal, not in this chat
(pasting a key into the conversation exposes it). Your job is to point the user at the script and
help interpret the result — do **not** ask them to paste keys here.

## What to do

1. Tell the user to run this in their terminal (suggest the `!` prefix so output lands in-session):

   ```
   ! ~/.claude/fusion/fusion-onboard
   ```

   Dry run first (writes nothing): `~/.claude/fusion/fusion-onboard --dry-run`

2. The script: shows current panelists + the provider catalog, lets them pick a provider, paste a
   key (hidden), **validates it with a live probe**, registers the provider in `providers.json`,
   and offers to enable a recommended model as a panelist. It is idempotent — existing secrets,
   providers, and panelists are preserved, and every config write is backed up.

3. After they finish: have them **restart Claude Code** (panel/commands load at launch), then run
   `/fusion-status` to confirm. Remind them `sensitive_ok` is `false` for new panelists — they
   should only flip it to `true` for a provider they trust not to retain their code.

## If the user can't use the terminal

Fall back to `/fusion-config` (set-key / add-provider) for a single provider, or have them edit
`~/.claude/fusion/secrets.env` (chmod 600) directly. The provider catalog lives at
`~/.claude/fusion/catalog.json` — read it to show available providers, endpoints, and recommended
models without exposing any key.
