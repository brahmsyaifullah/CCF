---
description: Show CCF analytics dashboard — run stats, latency, success rate, cost saved.
---

# /fusion-analytics

Print a text analytics dashboard over the Fusion telemetry log (`~/.claude/fusion/fusion.log`,
JSONL written by `fusion-call`). Shows total runs, success rate, per-panelist average latency
and success %, estimated cost saved vs OpenRouter Fusion, and the most recent errors.

Pass any arguments straight through — the only flag today is `--days N` (restrict the window
to the last N days; default is all time).

```bash
~/.claude/fusion/ccf-analytics "$ARGUMENTS"
```

After the dashboard prints, **summarize** it for the user in a short paragraph:

- total runs and overall success rate,
- which panelist is fastest / most reliable (avg latency + ok %), and any that are erroring,
- the estimated dollars saved vs paying OpenRouter Fusion per call,
- the most recent error(s) and what provider/model they hit.

If the dashboard reports zero runs, tell the user the log is empty — they need to run a
`/fusion` task first (telemetry is written on every panel call). If it reports a low success
rate or a panelist stuck on errors, suggest `/fusion-status` to probe reachability and
`/fusion-config` to check keys/timeouts.
