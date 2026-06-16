# Changelog

All notable changes to CCF (Claude Code Fusion) are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions are [SemVer](https://semver.org/).

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
