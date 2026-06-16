# CCF — Claude Code Fusion

Run a **multi-model fusion panel** inside Claude Code, on your **own subscription/flat-rate seats** —
no OpenRouter billing. A panel of models (GLM-5.2 1M, DeepSeek-V4-Pro 1M, optionally Sonnet/Opus)
answers a task **in parallel**; your running **Opus session judges** their drafts into structured
analysis (consensus / contradictions / unique insight / blind spots) and writes the final answer.

It's a local re-implementation of OpenRouter's "Fusion" pattern that bills nothing extra because the
panelists run on seats you already pay for.

```
            ┌── glm-5.2  (z.ai, 1M ctx) ──┐
your task ──┤                              ├──►  Opus judge ──►  synthesized answer
            └── deepseek-v4-pro (1M ctx) ──┘     (this session)
```

## Why

- **Diversity beats a single model.** A second/third independent draft catches blind spots.
- **No metered API.** Panelists run on z.ai / OpenCode subscriptions and your Claude sub.
- **Huge context.** Both default panelists carry **~1,048,576-token** windows (verified by
  needle-in-haystack — see [Context limits](#context-limits)).
- **Opus stays the author.** Panelists never write files; the orchestrator applies the code.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- `bash`, `jq`, `curl`, `awk`, `tar` (preinstalled on macOS/Linux except `jq`)
- A POSIX shell on Windows: **Git for Windows** (native) or **WSL**
- At least one provider key (z.ai and/or OpenCode). The Sonnet/Opus panelists use your `claude` CLI.

## Install

**macOS / Linux / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.sh | bash
```

**Windows (native PowerShell — needs Git Bash or WSL)**

```powershell
irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex
```

Or clone and run locally:

```bash
git clone https://github.com/brahmsyaifullah/CCF && cd CCF && ./install.sh
```

The installer copies the dispatcher, hooks, and slash commands into `~/.claude`, creates a
`secrets.env` (chmod 600) for your keys, and idempotently wires two hooks into `settings.json`
(backed up first). It **never** overwrites an existing `secrets.env`, `panel.json`, or `providers.json`.

Then:

1. Add keys — edit `~/.claude/fusion/secrets.env` or run `/fusion-config set-key`.
2. **Restart Claude Code** (hooks + commands load at launch).
3. `/fusion-status` to verify, then `/fusion <task>`.

## Usage

| Command | What it does |
|---------|--------------|
| `/fusion-onboard` | Guided setup — pick providers, add keys (validated), enable panelists. |
| `/fusion <task>` | Run a panel → judge → synthesis pass on demand (works anytime). |
| `/fusion-on` · `/fusion-off` | Toggle default-mode (proactive routing of substantial tasks). |
| `/fusion-status` | Show roster, providers, context limits, key presence, reachability. |
| `/fusion-config` | Add/edit providers, set/rotate keys, enable/disable panelists. |
| `/ccf-update` | Update CCF from GitHub (preserves your keys + config). |

Default-mode ships **off** — `/fusion` is always available explicitly.

## Onboarding

After install, run the guided setup in your terminal (keys are read hidden, never pasted into chat):

```bash
~/.claude/fusion/fusion-onboard           # interactive
~/.claude/fusion/fusion-onboard --dry-run # preview, writes nothing
```

It lists the provider catalog, takes a key, **validates it with a live probe**, registers the
provider, and enables a recommended model as a panelist — idempotent, every write backed up. Inside
Claude Code, `/fusion-onboard` points you to it.

## Providers & panelists

Default roster (`panel.json`):

- **Judge / writer:** Opus (your Claude session) — never demoted.
- **Panel (enabled):** `glm` (z.ai GLM-5.2) · `deepseek` (OpenCode-Go DeepSeek-V4-Pro).
- **Available (disabled):** `sonnet`, `opus` (your sub via `claude` CLI), `deepseek-flash`,
  `north-code` (free, non-zero-retention).

### Provider catalog

CCF ships a catalog (`~/.claude/fusion/catalog.json`) of 13 major providers with correct
OpenAI/Anthropic-compatible endpoints, recommended current models, and docs links — **disabled by
default**, so you enable only what you have keys for:

OpenAI · Anthropic · Google Gemini · DeepSeek · xAI Grok · Mistral · Moonshot (Kimi) · Groq ·
OpenRouter · Together · Fireworks · Cerebras · Qwen.

Enable one via `/fusion-onboard`, or `/fusion-config add-provider --from-catalog <name>`. The
catalog is read-only reference (refreshed on update); your live `providers.json` is never touched by it.
Non-catalog providers: `/fusion-config add-provider` (manual) + `set-key`.

### Panelist system prompt

Every panelist inherits `panel.json`'s `default_system_prompt` (role + output contract: answer
directly, propose-don't-act, flag risks with severity). Override one with a per-panelist
`system_prompt`, or set the default to `""` to disable. `fusion-call` injects it correctly per
transport (openai system message / anthropic top-level `system`).

## Context limits

Verified 2026-06-16 by needle-in-haystack (needle retrieved at 90% depth in a full ~1M-token prompt):

| Panelist | Provider | Ceiling | tok/char | Usable prompt |
|----------|----------|---------|----------|---------------|
| `glm` | z.ai GLM-5.2 | 1,048,576 tok | ~0.264 | ≤ ~3.9M chars |
| `deepseek` | OpenCode-Go DeepSeek-V4-Pro | 1,048,565 tok | ~0.295 | ≤ ~3.55M chars |
| `sonnet`/`opus` | claude sub | ~200K tok | ~0.25 | ≤ ~760K chars |

The dispatcher rejects oversize prompts **before** upload (with the exact char budget) instead of
letting the API return a silent empty response. Large 1M calls take ~40–60s.

## Security

- **No keys in this repo.** `secrets.env` is gitignored; only `secrets.env.example` is tracked.
- Keys live in `~/.claude/fusion/secrets.env` (chmod 600), referenced by `key_env` name only.
- **Zero-retention gating.** Free/pay-per-token providers are flagged `zero_retention=false`; the
  `/fusion` sensitivity gate refuses to send proprietary/customer code to any panelist marked
  `sensitive_ok=false`. Check `/fusion-status` — non-zero-retention providers show `FALSE!`.
- Rotate a key anytime with `/fusion-config set-key`.

## Updating

Notify-only by default: a throttled (~daily), fail-silent `SessionStart` hook checks GitHub and, if
a newer version exists, prints `[CCF] update available …`. Apply with:

```bash
/ccf-update            # or: bash ~/.claude/fusion/ccf-update.sh
~/.claude/fusion/ccf-update.sh --check    # report only
~/.claude/fusion/ccf-update.sh --force    # reinstall latest
```

Updates refresh **code only** (dispatcher, hooks, commands, `.dist` templates). Your `secrets.env`,
`panel.json`, and `providers.json` are preserved; new reference fields are reported for manual merge.
Skip the notifier at install with `--no-update-hook`.

## Uninstall

```bash
rm -rf ~/.claude/fusion ~/.claude/commands/fusion*.md ~/.claude/commands/ccf-update.md
# then remove the two CCF hook entries from ~/.claude/settings.json
# (a timestamped settings.json.ccf-bak.* backup was made at install)
```

## How it works

| File (installed under `~/.claude/`) | Role |
|------|------|
| `fusion/fusion-call` | Dispatcher. openai / anthropic / claude-cli transports. File-based body (1M-token safe past ARG_MAX), per-provider timeout, oversize-context guard, clear `ERR:` reporting. |
| `fusion/providers.json` | Transport registry: endpoint, auth, `key_env`, `max_tokens`, `request_timeout`, `max_context_tokens`, `tok_per_char`, `zero_retention`. |
| `fusion/panel.json` | Roster + `active` flag. `enabled` panelists form the default panel; `sensitive_ok` gates proprietary code. |
| `fusion/fusion-hook.sh` | `UserPromptSubmit` hook — default-mode reminder when active. |
| `fusion/ccf-check-update.sh` | `SessionStart` hook — throttled update notifier. |
| `fusion/secrets.env` | Your keys, chmod 600, never committed. |
| `commands/*.md` | The slash commands. |

## License

MIT — see [LICENSE](LICENSE).
