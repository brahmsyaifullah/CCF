---
description: Show Fusion state — active flag, panel roster, providers, key presence, and live reachability.
---

# /fusion-status

Report the current Fusion configuration. Run the block, then summarize.

```bash
F=~/.claude/fusion
echo "ACTIVE: $(jq -r '.active' "$F/panel.json")   (judge = running Opus session)"
echo
echo "PANEL:"
jq -r '.panel[] | "  [\(if .enabled then "x" else " " end)] \(.name)  \(.provider)/\(.model)  role=\(.role)  sensitive_ok=\(.sensitive_ok)"' "$F/panel.json"
echo
echo "PROVIDERS:"
jq -r '.providers | to_entries[] | "  \(.key)  type=\(.value.type)  ctx=\(.value.max_context_tokens // "?")tok(~\(if .value.tok_per_char then ((.value.max_context_tokens // 0)/.value.tok_per_char|floor) else 0 end)ch)  timeout=\(.value.request_timeout // 600)s  zero_retention=\(if .value.zero_retention==false then "FALSE!" elif .value.zero_retention then "true" else "n/a" end)  key_env=\(.value.key_env // "-")"' "$F/providers.json"
echo
echo "KEYS (presence only, never printed):"
set -a; . "$F/secrets.env" 2>/dev/null; set +a
for v in ZAI_API_KEY OPENCODE_GO_KEY OPENCODE_ZEN_KEY GEMINI_API_KEY MOONSHOT_API_KEY; do
  if [ -n "${!v:-}" ]; then echo "  $v = SET (…${!v: -4})"; else echo "  $v = unset"; fi
done
```

Optionally, for each enabled panelist, run a one-token reachability probe:

```bash
~/.claude/fusion/fusion-call <name> "Reply with exactly: OK" | head -1
```

For `--history`, summarize recent calls from the telemetry log instead of probing:

```bash
F=~/.claude/fusion
echo "Last call: $(cat "$F/.last-call" 2>/dev/null || echo none)"
if [ -f "$F/fusion.log" ]; then
  echo "Recent runs (last 10):"; tail -10 "$F/fusion.log" | jq -r '"  \(.ts)  \(.panelist)  \(.status)  \(.latency_s)s"'
  echo "Per-panelist avg latency + success rate:"
  jq -s -r 'group_by(.panelist)[] | "  \(.[0].panelist): \(length) runs, \((map(.latency_s)|add/length)|floor)s avg, \(((map(select(.status=="ok"))|length)*100/length)|floor)% ok"' "$F/fusion.log"
fi
```

Summarize: active y/n, which panelists are live vs misconfigured, any missing keys, and whether
each enabled panelist is on a zero-retention transport (SaaS safety). With `--history`, report the
recent-run stats above (latency, success rate per panelist) from `fusion.log`.
