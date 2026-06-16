---
description: Disable Fusion default-mode. /fusion still works on demand.
---

# /fusion-off

Set `active=false` in the roster.

```bash
F=~/.claude/fusion/panel.json
tmp=$(mktemp)
jq '.active=false' "$F" > "$tmp" && mv "$tmp" "$F"
echo "Fusion OFF (default-mode disabled). /fusion still works on demand."
```

Stop proactively routing tasks through the panel. Answer solo (Opus) unless the user explicitly
calls `/fusion`.
