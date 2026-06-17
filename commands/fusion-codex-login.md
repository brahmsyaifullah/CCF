---
description: Log in to Codex / GPT-5.5 via your browser (no codex CLI needed). Runs the OpenAI OAuth flow and stores tokens for the gpt panelist.
---

# /fusion-codex-login — browser login for the Codex panelist

Codex (GPT-5.5) auth uses a browser OAuth flow. It must run in the user's **terminal** (it opens a
browser and binds a local callback port) — not in this chat. Point the user at the helper; do not
ask them to paste tokens here.

## What to do

1. Tell the user to run, in their terminal (suggest the `!` prefix so output lands in-session):

   ```
   ! ~/.claude/fusion/ccf-codex-login
   ```

   - Headless / SSH (no local browser): `~/.claude/fusion/ccf-codex-login --no-browser` prints the
     URL to open on any machine; the callback still needs `localhost:1455` reachable (forward the
     port, or set `CCF_CODEX_PORT`).
   - Refresh an expired token without re-login: `~/.claude/fusion/ccf-codex-login --refresh`.

2. The flow: opens ChatGPT login → you authorize → tokens are written to `~/.codex/auth.json`
   (chmod 600, nested `tokens` layout). No codex CLI required; works whether or not one is installed.

3. After login, enable + verify the panelist:

   ```bash
   ~/.claude/fusion/fusion-call gpt "Reply with exactly: OK"
   ```

   If `gpt` isn't in `panel.json` yet, add it via `/fusion-config` (provider `codex`, model `gpt-5.5`)
   or merge from `panel.dist.json`, then `/fusion-config enable gpt`.

## Notes

- Tokens are the user's own ChatGPT/Codex subscription — `zero_retention=true`, `sensitive_ok=true`.
- `fusion-call` auto-refreshes the access token when it's within 120s of expiry (uses the stored
  refresh_token), so day-to-day use doesn't need re-login.
- Requires `python3` (stdlib only) for the login step; the runtime dispatcher stays bash.
