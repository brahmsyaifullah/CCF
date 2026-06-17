# CCF on Windows — Quickstart & Troubleshooting

CCF runs great on Windows. The installer **checks every requirement and installs whatever is
missing** (Git Bash, jq, curl, tar, Python), then installs CCF and offers the setup wizard.

## Easiest: one line

Open **PowerShell** (Start → type "PowerShell" → Enter) and paste:

```powershell
irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex
```

That single command:

1. Finds **winget** (or Chocolatey).
2. Installs anything missing — **Git for Windows** (provides `bash` + `curl`), **jq**, **Python 3**.
3. Refreshes your PATH so the new tools work immediately (no reboot).
4. Installs CCF into `%USERPROFILE%\.claude`.
5. Launches the setup wizard (pick providers → keys → models).

A **UAC prompt** may appear during package installs — that's expected; click Yes.

## Even easier: double-click

Download [`install-windows.bat`](../install-windows.bat) and **double-click it**. It runs the same
bootstrap with the execution policy handled for you, and pauses so you can read the output.

## Unattended / scripted

```powershell
irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex; # interactive
# or, from a checkout, fully automatic (installs deps + onboards without prompts):
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Yes
```

Flags: `-Yes` (no prompts), `-SkipOnboard`, `-NoHooks`, `-NoUpdateHook`, `-Wsl` (use WSL bash).

## After install

- **Restart Claude Code** (commands + hooks load at launch).
- In Claude Code: `/fusion-status` to verify, then `/fusion <task>`.
- To add/replace providers later: `python "%USERPROFILE%\.claude\fusion\ccf-onboard"` or `/fusion-setup`.

## Why does Windows need Git Bash / jq?

CCF's runtime dispatcher (`fusion-call`) is a POSIX shell script using `jq` + `curl` — the same on
every OS. On Windows that means a `bash` (Git Bash or WSL) plus `jq`. The installer handles both for
you. **The setup wizard itself is pure Python** and needs neither.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `irm ... \| iex` does nothing / "running scripts is disabled" | Run PowerShell as usual and prefix once: `powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 \| iex"` |
| "No winget or Chocolatey found" | Install **App Installer** from the Microsoft Store (gives `winget`), or [Chocolatey](https://chocolatey.org/install). Then re-run. |
| jq/git "not recognized" right after install | Close and reopen the terminal (PATH refresh), then re-run. The installer refreshes PATH in-session, but a fresh terminal always works. |
| "No bash available" | Install **Git for Windows** (https://git-scm.com/download/win), or run inside **WSL** and use `-Wsl`. |
| Behind a corporate proxy | Set `$env:HTTP_PROXY` / `$env:HTTPS_PROXY` before running, or install Git/jq/Python manually then re-run. |
| Prefer WSL entirely | Open your WSL distro and use the **Linux** one-liner: `curl -fsSL https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.sh \| bash` |

## Manual requirement install (if you'd rather)

```powershell
winget install Git.Git
winget install jqlang.jq
winget install Python.Python.3.12
# then:
irm https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.ps1 | iex
```

Or with Chocolatey: `choco install git jq python -y`.
