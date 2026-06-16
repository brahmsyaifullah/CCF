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

### list-catalog — show curated providers + recommended models
The catalog ships 20 major providers with correct endpoints + current models. Read-only reference.
```bash
jq -r '.providers[] | "\(.name)\t\(.type)\t\(.endpoint)\tkey_env=\(.key_env)\tmodels=\([.models[].model]|join(","))"' ~/.claude/fusion/catalog.json
```

### models.dev — the COMPLETE live registry (121+ providers, every model)
The curated catalog is a subset. For the full list, use `ccf-models` (reads https://models.dev/api.json):
```bash
~/.claude/fusion/ccf-models providers              # every provider id + name
~/.claude/fusion/ccf-models models <provider>      # a provider's models: context + $/Mtok
~/.claude/fusion/ccf-models show <provider>        # base url, env, docs + a ready providers.json entry
~/.claude/fusion/ccf-models add <provider> <model> [panelist]   # register provider + add panelist
```
After `add`, run `set-key <KEY_ENV>` (or `/fusion-onboard`) and probe. Providers with no direct base
URL on models.dev (e.g. Anthropic) are reachable via `openrouter` or the curated catalog instead.

### add-provider --from-catalog <name> — register a catalogued provider (preferred)
Copies the catalog entry into your live `providers.json` (no endpoint typing), then prompt for the key.
```bash
F=~/.claude/fusion/providers.json; C=~/.claude/fusion/catalog.json; tmp=$(mktemp)
e=$(jq -c --arg n "$NAME" '.providers[]|select(.name==$n)' "$C")
jq --arg n "$NAME" --argjson e "$e" \
  '.providers[$n]=($e|{type,endpoint,auth,key_env,max_tokens:8192,request_timeout:600,max_context_tokens:(.max_context_tokens//0),tok_per_char:(.tok_per_char//0),zero_retention:(.zero_retention//false)})' \
  "$F" > "$tmp" && mv "$tmp" "$F"
```
Then `set-key <key_env> <value>` and add a panelist. **Easiest path: just run `/fusion-onboard`** (terminal) — it does catalog pick → key → live probe → enable panelist, idempotently.

### add-provider (manual) — non-catalogued source
Required: `type` (`openai` | `anthropic` | `claude-cli`), `endpoint`, `auth` (`bearer` | `x-api-key`), `key_env`, `max_tokens`, `zero_retention`.
```bash
F=~/.claude/fusion/providers.json; tmp=$(mktemp)
jq --arg name "$NAME" '.providers[$name]={type:"openai",endpoint:"...",auth:"bearer",key_env:"NEW_KEY",max_tokens:8192,request_timeout:600,zero_retention:false}' "$F" > "$tmp" && mv "$tmp" "$F"
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

## To add Gemini, Moonshot/Kimi, OpenAI, Grok, Mistral, Groq, OpenRouter, Qwen …
They're all in the catalog (`~/.claude/fusion/catalog.json`). Use `add-provider --from-catalog <name>`
+ `set-key`, or just run `/fusion-onboard`. Direct API only — no Antigravity/OpenCode desktop app.

## System prompt (per panelist or global)
Panelists inherit `panel.json` `default_system_prompt`. Override one panelist with a `system_prompt`
field, or set `default_system_prompt` to `""` to disable. `fusion-call` injects it correctly per
transport (openai system message / anthropic top-level `system`).
```bash
F=~/.claude/fusion/panel.json; tmp=$(mktemp)
jq '(.panel[]|select(.name=="NAME")|.system_prompt)="Your override here."' "$F" > "$tmp" && mv "$tmp" "$F"
```
