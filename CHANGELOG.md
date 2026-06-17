# Changelog

All notable changes to CCF (Claude Code Fusion) are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions are [SemVer](https://semver.org/).

## [1.7.0] — 2026-06-17

### Added
- **Cross-platform onboarding** (`ccf-onboard`, Python stdlib): replaces the bash-only wizard for
  setup. Works the same on **macOS, Linux, and native Windows** — **no bash or jq needed to onboard**.
  Dependency doctor (OS-specific install hints), unified provider menu (default panel + 20-provider
  catalog), hidden key entry / browser-login (Codex) / keyless (Ollama), per-provider model choice,
  live probe, idempotent writes with backups. Modes: interactive, `--check`, `--list`,
  `--add P [MODEL]`, `--set-key ENV`, `--enable/--disable`.
- **`/fusion-setup`** — Claude-Code-driven setup. Say it (or "set up CCF" + the repo link) and the
  agent installs if needed, runs the dependency doctor, asks which providers + models you want
  (buttons, no secrets in chat), and walks you through key entry privately. No file editing.
- **Windows**: `install.ps1` now auto-installs `jq` via winget (the runtime needs it) and points to
  the Python wizard / `/fusion-setup`.

### Changed
- `install.sh` end-of-install offer now prefers the cross-platform Python wizard (falls back to the
  bash onboarder). README onboarding section rewritten around the two new paths.

## [1.6.3] — 2026-06-17

### Added
- README hero banner + Solo-vs-Fusion benchmark section with results image and badges.
- **`benchmark/RESULTS.md`** — published benchmark report (Fusion 196 vs Solo 192 / 200), blind-spot
  coverage, the deepseek truncation finding, and an explicit judge/solo bias disclosure.
- `assets/` — banner + solo-vs-fusion marketing images.

### Fixed
- `run-benchmark.sh`: replaced `mapfile` (bash 4+) with a bash-3.2-compatible read loop so the no-arg
  "run all tasks" path works on macOS (default bash is 3.2).

## [1.6.2] — 2026-06-17

### Fixed
- **deepseek / opencode-go usability**: raised opencode-go `max_tokens` 8192 → 64000. deepseek-v4-pro
  is a reasoning model — on complex tasks its internal reasoning consumed the entire 8192 output
  budget and the answer came back truncated (`finish_reason=length`). 8192 was a hard ceiling for
  every user on hard prompts. max_tokens is a *cap* (successful answers stop early), so the higher
  value only prevents truncation — no latency/cost penalty on a flat-rate sub. Verified: two
  benchmark tasks that returned 0.4KB truncated now return full 13–16KB answers.

## [1.6.1] — 2026-06-17

### Changed
- **Benchmark concurrency**: tasks now run **sequentially** (one at a time, never overlapping) while
  **panelists within a task run in parallel** (launched together, batch-awaited before judging).
  Previously every call was fully serial with a 3s gap between calls. `run-benchmark.sh`, the
  `/fusion-benchmark` command, and the benchmark README all updated. Verified: a 3-panelist task
  finishes in ~slowest-panelist time (85s) instead of the sum.
- `benchmark/results/` is now gitignored (generated output).

## [1.6.0] — 2026-06-17

### Added
- **Browser login for Codex** (`ccf-codex-login` + `/fusion-codex-login`): users no longer need the
  codex CLI or a pre-existing `~/.codex/auth.json`. Runs the OpenAI OAuth 2.0 + PKCE flow (same
  official client the codex CLI uses) on a local callback server, exchanges the code, derives the
  ChatGPT account id from the token JWT, and writes `~/.codex/auth.json` (chmod 600). Flow ported
  from NousResearch/hermes-agent's tested constants. Python 3 stdlib only (login-time; runtime stays bash).
  `--no-browser` for headless/SSH, `--refresh` to refresh without re-login.
- **Auto-refresh** in `fusion-call`: when the Codex access token is within 120s of expiry and a
  refresh_token exists, it refreshes silently before the call — no more mid-session expiry failures.

## [1.5.1] — 2026-06-17

### Fixed
- **Codex auth (#10)**: `fusion-call` read the access token + account ID from the wrong path —
  the codex CLI nests them under `.tokens.access_token` / `.tokens.account_id`, not top-level.
  Codex auth was failing for everyone ("no Codex token found"); now reads `.tokens.*` with a
  top-level fallback. Verified end-to-end against the live ChatGPT Codex backend.

## [1.5.0] — 2026-06-17

Benchmark slash commands + fair comparison design.

### Added
- **`/fusion-benchmark`** slash command: runs SOLO (orchestrator answers directly)
  vs FUSION (panel → orchestrator judges → synthesizes) on 5 coding tasks.
  Sequential only — no parallel panelist calls, respects rate limits. Outputs
  markdown files per task to `benchmark/results/`.
- **`/fusion-benchmark-report`** slash command: generates `REPORT.md` from
  benchmark results. Grades both arms on the rubric (correctness/completeness/
  blind spots/code quality), produces blind-spot analysis table, cost comparison,
  and honest verdict with caveats about orchestrator/judge bias.
- **`benchmark/run-benchmark.sh`**: standalone sequential data collector. Calls
  each enabled panelist one at a time with identical prompts, saves raw responses.
  Use without Claude Code for CI or batch collection.
- **Fair comparison design**: SOLO = orchestrator answers alone (no panelists
  called). FUSION = orchestrator calls panelists → judges. This isolates the
  panel's value-add. Documents the bias warning: if orchestrator = same model
  family as a panelist, the test is not fair.

## [1.4.0] — 2026-06-17

Five new features: Codex/GPT-5.5 panelist (#10), Tavily web search (#11), fusion verification
fixes (#12), analytics dashboard (#13), benchmark suite (#14).

### Added
- **Codex/GPT-5.5 panelist** (#10): new `codex-responses` transport. Auto-reads `~/.codex/auth.json`,
  extracts ChatGPT-Account-ID from JWT, injects Cloudflare headers (`User-Agent: codex_cli_rs/0.0.0`,
  `originator`, `ChatGPT-Account-ID`). Requires SSE streaming (`stream:true`), `store:false`, and
  `instructions` field. Does NOT support `max_output_tokens`. Disabled by default — enable in panel.json.
- **Tavily web search** (#11): `--search` flag on `fusion-call` enables multi-turn tool calling.
  Panelists request searches via standard function calling → CCF calls Tavily locally → results fed
  back. Max 3 rounds (override with `MAX_SEARCH_TURNS`). Zero change without `--search`.
- **Analytics dashboard** (#13): `/fusion-analytics` slash command. Pure bash + jq text dashboard
  reading `fusion.log`. Shows total runs, success rate, per-panelist latency + ok%, cost saved vs
  OpenRouter Fusion ($0.50/call), recent errors.
- **Benchmark suite** (#14): 5 real coding tasks (bug fix, security, refactor, architecture,
  concurrency) with 0-100 grading rubric. Two new slash commands: `/fusion-benchmark` runs
  SOLO (orchestrator answers directly) vs FUSION (panel → orchestrator judges) sequentially;
  `/fusion-benchmark-report` generates comparison REPORT.md with blind-spot analysis. Standalone
  `benchmark/run-benchmark.sh` collects raw panelist responses without AI judgment. Sequential
  only — no parallel calls, respects rate limits.

### Changed
- **Fusion verification** (#12): Judge JSON schema now matches OpenRouter (`partial_coverage`,
  `unique_insights`). `FUSION CONFIRMED: N/N` line is mandatory. `failed_models` tracked. Judge
  instructed to verify claims via tools. Warning when <2 panelists respond.

## [1.3.0] — 2026-06-17

Roadmap items: test suite + CI (#1), dispatcher hardening (#3), retry/fallback (#4), logging (#5),
progress (#6), panel presets (#8), Homebrew formula (#9).

### Added
- **Retry/fallback** (#4): per-provider `max_retries` (default 0) with linear backoff; transient
  network failures retried, full-budget timeouts not.
- **Telemetry log** (#5): each call appends JSONL to `~/.claude/fusion/fusion.log`
  (panelist, provider, model, status, latency_s, bytes); auto-rotates at ~5 MB.
- **Progress** (#6): `~/.claude/fusion/.last-call` written each call; `/fusion-status --history`
  shows recent runs + per-panelist avg latency and success rate.
- **Dispatcher hardening** (#3): curl exit-code → actionable messages (DNS 6, connect 7, SSL 35/51/60,
  timeout 28); unparseable (non-JSON) responses reported instead of crashing.
- **Panel presets** (#8): `coding`, `research`, `writing`, `budget`, `max` in `config/presets/`;
  `/fusion-config load-preset` / `save-preset` (backs up, never touches secrets).
- **Test suite + CI** (#1): bats offline tests for the dispatcher error paths (unknown panelist/provider,
  empty prompt, missing key, context guard) + JSON/preset validity; GitHub Actions runs them on
  Ubuntu + macOS with a secret scan.
- **Homebrew formula** (#9): `Formula/ccf.rb` (+ `docs/HOMEBREW.md`) — `brew install` stages CCF and
  exposes a `ccf` command that runs the installer. Tap repo setup documented.

## [1.2.0] — 2026-06-17

### Added
- **Provider catalog expanded to 20** (from 13): added Kimi-Code, MiniMax, Novita, HuggingFace,
  Xiaomi MiMo, Ollama (cloud), and Ollama (local, keyless). Updated Gemini (3.x, 2M ctx), Groq
  (Llama-4 Scout), and OpenRouter model lists to current IDs. Endpoints are full chat-completion URLs.
- **Keyless providers**: `fusion-call` now supports providers with an empty/`none` `key_env`
  (no `Authorization` header) — enables self-hosted Ollama (`localhost:11434`) for air-gapped,
  zero-retention panels.
- **`ccf-models` — live models.dev registry browser/installer**: the curated catalog is a subset;
  `ccf-models` reads https://models.dev/api.json (121+ providers, every model with context + cost,
  the same DB Hermes uses) and can `providers` / `models <p>` / `show <p>` / `add <p> <model>`
  (registers the provider + adds a panelist). Cached 24h, honors `CLAUDE_HOME`.

### Notes
- Catalog model IDs are current-best starters with per-provider docs links; verify the latest at the
  linked docs. OAuth-only providers (Qwen portal) and endpoint-less providers (Arcee) are omitted —
  the dispatcher needs an endpoint plus bearer/x-api-key auth or a keyless host.

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
