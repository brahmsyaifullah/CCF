#!/usr/bin/env bash
# UserPromptSubmit hook for the Fusion system.
# When panel.json .active=true and the prompt looks like a real task, inject a
# reminder so the orchestrator routes substantial work through /fusion. This is the
# harness-enforced layer: it fires on every prompt regardless of session/context drift.
# It does NOT call models itself — it only nudges; the orchestrator still applies the
# triviality + sensitivity judgement. Always exits 0 (never blocks input).
set -euo pipefail

FDIR="$HOME/.claude/fusion"
PANEL="$FDIR/panel.json"
[ -f "$PANEL" ] || exit 0

active=$(jq -r '.active // false' "$PANEL" 2>/dev/null || echo false)
[ "$active" = "true" ] || exit 0

input=$(cat 2>/dev/null || true)
prompt=$(jq -r '.prompt // ""' <<<"$input" 2>/dev/null || echo "")
[ -z "$prompt" ] && exit 0

# Skip explicit slash commands — already intentional.
case "$prompt" in
  /*) exit 0 ;;
esac

# Skip trivial / short chatter.
[ "${#prompt}" -lt 24 ] && exit 0
low=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
case "$low" in
  hi|hello|hey|*"thank you"*|*"thanks"*|*"what time"*|*"how are you"*|*"good morning"*) exit 0 ;;
esac

panel=$(jq -r '[.panel[]|select(.enabled)|.name]|join(" + ")' "$PANEL" 2>/dev/null || echo "")
[ -z "$panel" ] && exit 0

cat <<EOF
[Fusion ACTIVE] If this is a non-trivial implementation, design, review, debug, or analysis task, route it through the /fusion flow (panel -> Opus judge -> synthesis) with panelists: ${panel}. Call them in parallel via ~/.claude/fusion/fusion-call, apply the sensitivity gate (never send proprietary/customer code to a sensitive_ok=false panelist), then judge and synthesize. Skip fusion only for genuinely trivial Q&A. User enabled forced mode — do not silently answer solo on substantial work.
EOF
exit 0
