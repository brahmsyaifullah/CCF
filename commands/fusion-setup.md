---
description: Guided CCF setup driven by Claude Code — installs if needed, checks dependencies, helps the user pick providers + models, and walks them through key entry. Works on macOS, Linux, and Windows.
---

# /fusion-setup — let Claude Code set CCF up for you

Goal: get the user from zero to a working panel with **no manual file editing**, on any OS, whether
they ran the installer or just said "set this up". You (the agent) drive it; the user only picks
options and pastes keys **into their own terminal** (never into this chat).

Use the `ccf-onboard` helper — it's **Python stdlib, cross-platform (Windows native too), needs no
jq or bash**. Detect the user's OS first (`uname` / `$OS`) and adapt commands.

## Step 0 — Install if missing

If `~/.claude/fusion/ccf-onboard` doesn't exist, CCF isn't installed. Install it:

- macOS / Linux / WSL: `curl -fsSL https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.sh | bash`
- Windows (PowerShell): `irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex`

If the user gave a repo link or a local clone, run its `install.sh` / `install.ps1` instead.

## Step 1 — Dependency doctor

```bash
python3 ~/.claude/fusion/ccf-onboard --check
```

If it reports `jq` / `curl` missing (the **runtime** dispatcher needs them, even though onboarding
doesn't), offer to install them and run the OS-appropriate command **with the user's OK**:

- macOS: `brew install jq`
- Debian/Ubuntu/WSL: `sudo apt-get install -y jq curl`
- Windows: `winget install jqlang.jq` (and install **Git for Windows** for bash, or use WSL)

## Step 2 — Pick providers + models (no secrets — safe to do in chat)

List what's available, then **use AskUserQuestion** to let the user pick (multi-select):

```bash
python3 ~/.claude/fusion/ccf-onboard --list
```

Ask: which providers do they want as panelists? Surface the sensible defaults (`glm`, `deepseek`,
and `gpt`/Codex), and note that `gpt` (Codex) and `sonnet`/`opus` need no API key. For each chosen
provider with multiple models, ask which model.

## Step 3 — Register each choice (no key needed here)

For every selection, register it non-interactively:

```bash
python3 ~/.claude/fusion/ccf-onboard --add <provider> <model> --name <panelist-name>
```

## Step 4 — Keys (the user does this privately)

Keys must **never** be pasted into this chat. For each key-needing provider, have the user run, in
their terminal (suggest the `!` prefix so output returns here):

```bash
! python3 ~/.claude/fusion/ccf-onboard --set-key <KEY_ENV>      # prompts hidden, stores chmod 600
```

- Codex / GPT-5.5: `! ~/.claude/fusion/ccf-codex-login` (browser login, no key to paste).
- `sonnet` / `opus`: nothing — they use the local `claude` CLI.
- Local Ollama: nothing — keyless.

## Step 5 — Verify + finish

```bash
python3 ~/.claude/fusion/ccf-onboard --check
~/.claude/fusion/fusion-call <panelist> "Reply with exactly: OK"     # probe each enabled panelist
```

Tell the user to **restart Claude Code** (commands/hooks load at launch), then `/fusion-status` and
`/fusion <task>`. Remind them `sensitive_ok` defaults to false for non-zero-retention providers.

## Notes
- Prefer the interactive wizard when the user is at a terminal: `! python3 ~/.claude/fusion/ccf-onboard`
  (does steps 2–5 in one flow, hidden key entry). Use the agent-driven `--add` / `--set-key` split
  when guiding from chat.
- Everything is idempotent and backed up; existing keys/panelists are never clobbered without a confirm.
