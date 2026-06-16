#!/usr/bin/env bash
# CCF — Claude Code Fusion installer (macOS / Linux / WSL).
#
#   ./install.sh                     # install from this checkout, or download latest
#   curl -fsSL https://raw.githubusercontent.com/brahmsyaifullah/CCF/main/install.sh | bash
#
# Flags:
#   --no-update-hook   skip the SessionStart update-notifier hook
#   --no-hooks         skip ALL hook wiring (UserPromptSubmit + SessionStart)
#   --dir <path>       target Claude dir (default: $CLAUDE_HOME or ~/.claude)
set -euo pipefail

REPO_SLUG="brahmsyaifullah/CCF"
BRANCH="${CCF_BRANCH:-main}"
WANT_UPDATE_HOOK=1
WANT_HOOKS=1
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"

while [ $# -gt 0 ]; do
  case "$1" in
    --no-update-hook) WANT_UPDATE_HOOK=0 ;;
    --no-hooks) WANT_HOOKS=0 ;;
    --dir) CLAUDE_DIR="$2"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '  %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

echo "== CCF — Claude Code Fusion installer =="

# --- 1. dependency check ---
missing=""
for t in bash jq curl awk tar; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
[ -n "$missing" ] && die "missing required tools:$missing
  macOS:  brew install jq
  Debian: sudo apt-get install -y jq curl
  (curl/awk/tar/bash are usually preinstalled)"
command -v claude >/dev/null 2>&1 || say "note: 'claude' CLI not on PATH — the sonnet/opus panelists need it (the GLM/DeepSeek panelists do not)."

# --- 2. locate source (local checkout or download) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLEAN_SRC=""
if [ -f "$SCRIPT_DIR/bin/fusion-call" ]; then
  SRC="$SCRIPT_DIR"; say "source: local checkout ($SRC)"
else
  TMP="$(mktemp -d)"; CLEAN_SRC="$TMP"; trap '[ -n "$CLEAN_SRC" ] && rm -rf "$CLEAN_SRC"' EXIT
  say "source: downloading $REPO_SLUG@$BRANCH ..."
  curl -fsSL -m 60 "https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$BRANCH" -o "$TMP/ccf.tgz" \
    || die "download failed — check network or REPO_SLUG"
  tar -xzf "$TMP/ccf.tgz" -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 1 -mindepth 1 -type d ! -name '.*' | head -1)"
  [ -f "$SRC/bin/fusion-call" ] || die "extracted archive missing bin/fusion-call"
fi

FUSION_DIR="$CLAUDE_DIR/fusion"
CMD_DIR="$CLAUDE_DIR/commands"
mkdir -p "$FUSION_DIR" "$CMD_DIR"

# --- 3. install code (always overwrite) ---
install -m 0755 "$SRC/bin/fusion-call"          "$FUSION_DIR/fusion-call"
install -m 0755 "$SRC/hooks/fusion-hook.sh"     "$FUSION_DIR/fusion-hook.sh"
install -m 0755 "$SRC/bin/ccf-update.sh"        "$FUSION_DIR/ccf-update.sh"
install -m 0755 "$SRC/bin/ccf-check-update.sh"  "$FUSION_DIR/ccf-check-update.sh"
install -m 0755 "$SRC/bin/fusion-onboard"       "$FUSION_DIR/fusion-onboard"
install -m 0755 "$SRC/bin/ccf-models"           "$FUSION_DIR/ccf-models"
for f in "$SRC/commands/"*.md; do install -m 0644 "$f" "$CMD_DIR/$(basename "$f")"; done
install -m 0644 "$SRC/config/providers.dist.json" "$FUSION_DIR/providers.dist.json"
install -m 0644 "$SRC/config/panel.dist.json"     "$FUSION_DIR/panel.dist.json"
install -m 0644 "$SRC/config/secrets.env.example" "$FUSION_DIR/secrets.env.example"
install -m 0644 "$SRC/config/catalog.json"        "$FUSION_DIR/catalog.json"
install -m 0644 "$SRC/VERSION"                    "$FUSION_DIR/VERSION"
printf '%s\n' "$REPO_SLUG" > "$FUSION_DIR/.ccf-source"
say "installed dispatcher, hooks, update scripts, and slash commands"

# --- 4. config: create only if missing (never clobber user edits / keys) ---
[ -f "$FUSION_DIR/providers.json" ] || { install -m 0644 "$SRC/config/providers.dist.json" "$FUSION_DIR/providers.json"; say "created providers.json"; }
[ -f "$FUSION_DIR/panel.json" ]     || { install -m 0644 "$SRC/config/panel.dist.json"     "$FUSION_DIR/panel.json";     say "created panel.json"; }
if [ -f "$FUSION_DIR/secrets.env" ]; then
  say "kept existing secrets.env"
else
  install -m 0600 "$SRC/config/secrets.env.example" "$FUSION_DIR/secrets.env"
  say "created secrets.env (chmod 600) — fill in your keys"
fi

# --- 5. wire settings.json hooks (idempotent, with backup) ---
if [ "$WANT_HOOKS" = "1" ]; then
  SETTINGS="$CLAUDE_DIR/settings.json"
  UPH="bash \"$FUSION_DIR/fusion-hook.sh\""
  SSH="bash \"$FUSION_DIR/ccf-check-update.sh\""
  cur='{}'; [ -s "$SETTINGS" ] && cur="$(cat "$SETTINGS")"
  echo "$cur" | jq empty 2>/dev/null || die "existing settings.json is not valid JSON — fix it, then rerun"
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.ccf-bak.$(date +%Y%m%d%H%M%S)"
  add_ssh="$WANT_UPDATE_HOOK"
  merged="$(echo "$cur" | jq \
    --arg uph "$UPH" --arg ssh "$SSH" --argjson add_ssh "$add_ssh" '
    .hooks = (.hooks // {})
    | .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // [])
    | (if ([ .hooks.UserPromptSubmit[]?.hooks[]?.command ] | map(. // "" | contains("fusion-hook.sh")) | any)
        then . else .hooks.UserPromptSubmit += [{hooks:[{type:"command",command:$uph}]}] end)
    | (if $add_ssh == 1 then
         .hooks.SessionStart = (.hooks.SessionStart // [])
         | (if ([ .hooks.SessionStart[]?.hooks[]?.command ] | map(. // "" | contains("ccf-check-update.sh")) | any)
             then . else .hooks.SessionStart += [{hooks:[{type:"command",command:$ssh}]}] end)
       else . end)
  ')"
  printf '%s\n' "$merged" > "$SETTINGS"
  say "wired UserPromptSubmit hook (fusion default-mode reminder)"
  [ "$WANT_UPDATE_HOOK" = "1" ] && say "wired SessionStart hook (update notifier, throttled ~daily)"
  say "backup: $SETTINGS.ccf-bak.*"
else
  say "skipped hook wiring (--no-hooks)"
fi

cat <<EOF

== Done. CCF v$(cat "$FUSION_DIR/VERSION") installed to $CLAUDE_DIR ==

Next:
  1. Add your API keys:   \$EDITOR "$FUSION_DIR/secrets.env"
                          (or run /fusion-config set-key inside Claude Code)
  2. Restart Claude Code  (hooks + slash commands load at launch)
  3. Try it:              /fusion-status   then   /fusion <task>

Default-mode is OFF. Turn proactive routing on with /fusion-on (off with /fusion-off).
Update later with /ccf-update.
EOF

# Offer interactive onboarding (only with a real terminal on both stdin and stdout —
# never under curl|bash, where stdin is the piped script).
if [ -t 0 ] && [ -t 1 ]; then
  printf '\nRun interactive setup now (pick providers, add keys, enable panelists)? [y/N] '
  read -r _ans || _ans=""
  case "$_ans" in
    y|Y) exec "$FUSION_DIR/fusion-onboard" ;;
    *)   say "Skipped. Run it anytime:  $FUSION_DIR/fusion-onboard   (or /fusion-onboard)" ;;
  esac
else
  say "Tip: run  $FUSION_DIR/fusion-onboard  (or /fusion-onboard) for guided provider/key setup."
fi
