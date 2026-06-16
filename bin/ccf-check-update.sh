#!/usr/bin/env bash
# ccf-check-update.sh — lightweight, throttled update notifier for the SessionStart hook.
# Fail-silent and fast: never blocks a session, never errors out, checks GitHub at most
# once per CCF_CHECK_INTERVAL seconds (default 24h). Prints ONE line if a newer version exists.
set -uo pipefail

CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
FUSION_DIR="$CLAUDE_DIR/fusion"
STAMP="$FUSION_DIR/.last-update-check"
SRC_FILE="$FUSION_DIR/.ccf-source"
BRANCH="${CCF_BRANCH:-main}"
INTERVAL="${CCF_CHECK_INTERVAL:-86400}"

# never let this hook break a session
exit_clean() { exit 0; }
trap exit_clean ERR

[ -d "$FUSION_DIR" ] || exit 0

now=$(date +%s)
if [ -f "$STAMP" ]; then
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  [ $(( now - last )) -lt "$INTERVAL" ] && exit 0   # checked recently — stay quiet
fi
echo "$now" > "$STAMP" 2>/dev/null || true

slug="brahmsyaifullah/CCF"
[ -f "$SRC_FILE" ] && slug="$(cat "$SRC_FILE" 2>/dev/null || echo "$slug")"

local_ver="0.0.0"; [ -f "$FUSION_DIR/VERSION" ] && local_ver="$(tr -d '[:space:]' < "$FUSION_DIR/VERSION" 2>/dev/null)"
remote_ver="$(curl -fsSL -m 3 "https://raw.githubusercontent.com/$slug/$BRANCH/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
[ -z "$remote_ver" ] && exit 0   # offline / unreachable — silent

if [ "$remote_ver" != "$local_ver" ]; then
  newest="$(printf '%s\n%s\n' "$local_ver" "$remote_ver" | sort -V | tail -1)"
  [ "$newest" = "$remote_ver" ] && echo "[CCF] update available: $local_ver -> $remote_ver. Run /ccf-update to upgrade."
fi
exit 0
