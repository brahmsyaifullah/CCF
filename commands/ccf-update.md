---
description: Update CCF (Claude Code Fusion) from GitHub — refreshes the dispatcher, hooks, and slash commands while preserving your secrets and config.
---

# /ccf-update — update Claude Code Fusion

Pulls the latest CCF release from GitHub and reinstalls the code into `~/.claude`. Your
`secrets.env`, `panel.json`, and `providers.json` are left untouched.

## Run

```bash
bash ~/.claude/fusion/ccf-update.sh "$ARGUMENTS"
```

- no args — update only if a newer version exists
- `--check` — report installed vs remote version, change nothing
- `--force` — reinstall the latest even if versions match

## After updating

- If the dispatcher, hooks, or commands changed, tell the user to **restart Claude Code**
  (hooks and slash commands load at launch).
- If the output notes new `providers.dist.json` fields (e.g. context limits), offer to merge
  them into the user's live `providers.json` via `/fusion-config`.
- Summarize: old version → new version, and whether a restart is needed.
