---
description: Configure Fusion — add/edit providers, set or rotate API keys, enable/disable panelists, change models.
---

# /fusion-config

Interactive manager for the Fusion system. Files live in `~/.claude/fusion/`:
`providers.json` (endpoints/transport), `panel.json` (roster), `secrets.env` (keys, chmod 600).

Parse `$ARGUMENTS` if given (e.g. `set-key OPENCODE_GO_KEY`, `enable sonnet`, `add-provider`,
`set-model deepseek deepseek-v4-flash`). Otherwise use `AskUserQuestion` to pick an action:

## Actions

### set-key — add or rotate an API key
Write to `secrets.env` while preserving 600 perms and never echoing the value. Ask the user to
paste the key (warn: pasting in chat exposes it — prefer they confirm they'll rotate, or set it
themselves via `! printf 'NAME=val\n' >> ~/.claude/fusion/secrets.env`).

```bash
# replace-or-append KEY in secrets.env, keep mode 600
F=~/.claude/fusion/secrets.env; K="$1"; V="$2"
umask 177
tmp=$(mktemp); grep -v "^${K}=" "$F" 2>/dev/null > "$tmp" || true
printf '%s=%s\n' "$K" "$V" >> "$tmp"
mv "$tmp" "$F"; chmod 600 "$F"
echo "$K updated (…${V: -4})"
```

### add-provider — register a new model source
Append to `providers.json`. Required: `type` (`openai` | `anthropic` | `claude-cli`),
`endpoint`, `auth` (`bearer` | `x-api-key`), `key_env`, `max_tokens`, `zero_retention`.

```bash
F=~/.claude/fusion/providers.json; tmp=$(mktemp)
jq --arg name "$NAME" '.providers[$name]={type:"openai",endpoint:"...",auth:"bearer",key_env:"NEW_KEY",max_tokens:8192,zero_retention:true}' "$F" > "$tmp" && mv "$tmp" "$F"
```
Then `set-key NEW_KEY <value>` and add a panelist that uses it.

### add-panelist / set-model / enable / disable
```bash
F=~/.claude/fusion/panel.json; tmp=$(mktemp)
# add:
jq '.panel += [{name:"NAME",provider:"PROV",model:"MODEL",role:"ROLE",enabled:true,sensitive_ok:true}]' "$F" > "$tmp" && mv "$tmp" "$F"
# enable/disable/change model:
jq '(.panel[] | select(.name=="NAME") | .enabled) = true'   "$F" > "$tmp" && mv "$tmp" "$F"
jq '(.panel[] | select(.name=="NAME") | .model)   = "X"'    "$F" > "$tmp" && mv "$tmp" "$F"
```

### set-sensitive — mark a panelist safe/unsafe for proprietary code
Set `sensitive_ok` true only for zero-retention, trusted providers. Free tiers → false.

## After any change
Run a reachability probe and report:
```bash
~/.claude/fusion/fusion-call <name> "Reply with exactly: OK" | head -1
```

## Known providers (already wired)
- `claude-sub` — Anthropic subscription via local `claude` CLI (no key; Opus/Sonnet panelists)
- `zai` — z.ai GLM-5.2, 1M context, zero-retention (`ZAI_API_KEY`)
- `opencode-go` — OpenCode Go flat-rate sub, DeepSeek/GLM/etc., zero-retention (`OPENCODE_GO_KEY`)
- `opencode-zen` — OpenCode Zen pay-per-token; free models NOT zero-retention (`OPENCODE_ZEN_KEY`)

## To add Gemini or Moonshot/Kimi later
`add-provider` with their OpenAI-compatible endpoint + `set-key`. No Antigravity/OpenCode app
needed — direct API only.
