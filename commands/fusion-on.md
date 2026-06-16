---
description: Enable Fusion default-mode — the orchestrator proactively routes substantial coding tasks through the multi-model panel.
---

# /fusion-on

Set `active=true` in the roster so Fusion engages by default.

```bash
F=~/.claude/fusion/panel.json
tmp=$(mktemp)
jq '.active=true' "$F" > "$tmp" && mv "$tmp" "$F"
echo "Fusion ACTIVE. Enabled panelists:"
jq -r '.panel[] | select(.enabled) | "  - \(.name) [\(.role)] via \(.provider)/\(.model)"' "$F"
```

## Effect

While `active=true`, proactively run non-trivial implementation, design, review, or analysis tasks
through the `/fusion` flow (panel → judge → synthesis) instead of answering solo — unless the user
says otherwise or the task is trivial. The sensitivity gate in `/fusion` still applies.

**Note:** this is a behavioral flag the orchestrator honors, not OS-level enforcement. For hard
auto-engagement on every task, a PreToolUse/UserPromptSubmit hook would be required — offer to wire
one if the user wants it guaranteed. `/fusion` always works on demand regardless of this flag.

Turn off with `/fusion-off`.
