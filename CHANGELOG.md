# Changelog

All notable changes to CCF (Claude Code Fusion) are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions are [SemVer](https://semver.org/).

## [1.1.0] — 2026-06-17

### Added
- **Interactive onboarding** (`fusion-onboard` + `/fusion-onboard`): pick a provider from the
  catalog, paste a key (hidden, never in chat), **validate with a live probe via `fusion-call`**,
  register the provider, and enable a recommended model as a panelist. Idempotent, additive,
  backs up every config write, `--dry-run` supported. `install.sh` offers it at the end (terminal only).
- **Provider catalog** (`config/catalog.json`): 13 major providers (OpenAI, Anthropic, Gemini,
  DeepSeek, xAI Grok, Mistral, Moonshot/Kimi, Groq, OpenRouter, Together, Fireworks, Cerebras,
  Qwen) with correct OpenAI/Anthropic-compatible endpoints, recommended current models, docs links,
  and context metadata. Read-only reference, refreshed on update. `/fusion-config` gains
  `list-catalog` and `add-provider --from-catalog <name>`.
- **System-prompt support** in `fusion-call`: per-panelist `system_prompt` or panel-wide
  `default_system_prompt` (shipped in `panel.dist.json`). Injected correctly per transport
  (openai system message / anthropic top-level `system`). Absent ⇒ no system message (backward compatible).
- `CALL_MAX_TOKENS` and `CALL_SYSTEM` per-call env overrides.

### Fixed
- Dispatcher no longer mislabels output truncation as a context error: `finish_reason=length` /
  `stop_reason=max_tokens` now report "output truncated — raise CALL_MAX_TOKENS", distinct from a
  real context-window overflow.
- Runtime scripts (`fusion-call`, `fusion-hook.sh`) now honor `CLAUDE_HOME` instead of hardcoding
  `$HOME/.claude` — fixes custom config-dir installs.

## [1.0.0] — 2026-06-17

First public release.

### Added
- **Multi-model fusion** (`/fusion`): panel → Opus judge → synthesis on your own seats.
- **Dispatcher** (`fusion-call`): openai / anthropic / claude-cli transports.
  - File-based request body — handles up to ~1M-token prompts past `ARG_MAX`.
  - Per-provider `request_timeout` (default 600s, `CALL_TIMEOUT` override) + `--connect-timeout`.
  - **Context-window guard** — rejects oversize prompts before upload using
    `max_context_tokens` / `tok_per_char`, with the exact char budget in the error.
  - Clear `ERR:` on timeout and on empty-but-200 (`model_context_window_exceeded`) responses.
  - `max_tokens` floor of 512 so reasoning models don't starve their own answer.
- **Slash commands**: `/fusion`, `/fusion-on`, `/fusion-off`, `/fusion-status`, `/fusion-config`,
  `/ccf-update`.
- **Hooks**: `UserPromptSubmit` default-mode reminder; `SessionStart` throttled update notifier.
- **Cross-platform installers**: `install.sh` (macOS/Linux/WSL) and `install.ps1`
  (Windows native via Git Bash/WSL). Idempotent `settings.json` hook merge with backup.
- **GitHub auto-update**: `ccf-update.sh` (tarball-based, preserves secrets + user config) and
  `ccf-check-update.sh` (notify-only).
- Verified context ceilings (needle-in-haystack): glm-5.2 1,048,576 tok (~0.264 tok/char),
  deepseek-v4-pro 1,048,565 tok (~0.295 tok/char).

### Security
- `secrets.env` gitignored; only `secrets.env.example` tracked. Keys referenced by `key_env` name.
- Zero-retention gating; `/fusion-status` flags non-zero-retention providers as `FALSE!`.
