---
description: Run a multi-model Fusion pass (panel → judge → synthesis) on a task, using your own subscription/sub-flat-rate seats. Opus judges; GLM/DeepSeek/etc. are panelists.
---

# /fusion — Multi-Model Fusion (panel → judge → synthesis)

Replicates OpenRouter's Fusion logic locally on the user's own seats. **No OpenRouter billing.**
A panel of models answers in parallel, the orchestrator (Opus, this session) judges their
answers into structured analysis, then writes the final answer from that analysis.

**Roster + transports:** `~/.claude/fusion/panel.json`, `providers.json`, dispatcher
`~/.claude/fusion/fusion-call`. Judge = this running Opus session. Panelists are called via the
dispatcher (z.ai GLM-5.2 1M, OpenCode-Go DeepSeek, optional Sonnet/Opus via the local `claude` CLI).

## Usage

```
/fusion <task or question>
```

If `$ARGUMENTS` is empty, fall back to the current task / uncommitted changes.

## Workflow

### Step 1 — Resolve the panel

```bash
jq -r '.panel[] | select(.enabled) | "\(.name)\t\(.provider)\t\(.model)\t\(.role)\tsensitive_ok=\(.sensitive_ok)"' ~/.claude/fusion/panel.json
```

### Step 2 — Sensitivity gate (SaaS-critical)

Decide if the task exposes proprietary/customer code or secrets.
- If yes: **exclude** any panelist with `sensitive_ok=false` OR whose provider has
  `zero_retention=false` (check `providers.json`). State which panelists were skipped and why.
- If no (generic logic, public API, throwaway): all enabled panelists may run.

### Step 3 — Build the panelist prompt

Compose one prompt with: the task, the relevant file contents/context, and an explicit output
contract (e.g. "Return your proposed solution + reasoning. Flag risks and edge cases."). Keep it
identical across panelists so the judge compares like-for-like.

**Large context (verified 2026-06-16):** both `glm` and `deepseek` carry ~1,048,576-token windows.
Usable char budgets: **glm ≤ ~3.9M chars**, **deepseek ≤ ~3.55M chars** (deepseek tokenizes denser).
`fusion-call` guards this automatically — an oversize prompt returns `ERR: prompt ~N tok exceeds …`
*before* any upload, with the exact char ceiling. If you hit it, split the context across calls or
drop the lower-signal files. `claude-sub` (sonnet/opus) panelists are ~200K — don't send 1M to them.

### Step 4 — Run the panel IN PARALLEL

Launch every selected panelist concurrently — multiple Bash calls in a single message (or
`run_in_background: true`). Pipe the prompt on stdin:

```bash
~/.claude/fusion/fusion-call <name> <<'PROMPT'
<the shared panelist prompt>
PROMPT
```

Wait for all to return. Treat any `ERR:` line as that panelist abstaining (note it, continue).
Common `ERR:` causes: `timeout after Ns` (raise `CALL_TIMEOUT`), `prompt ~N tok exceeds …window`
(split/shrink context), `empty output (stop_reason=…)` (context exceeded), missing key.
Large 1M-context calls take ~40–60s — prefer `run_in_background: true` for those.

### Step 5 — JUDGE (you, Opus)

Compare the drafts. Produce the Fusion analysis object:

```json
{
  "consensus":      ["points all/most panelists agree on — higher confidence"],
  "contradictions": ["where panelists disagree + which is better-supported"],
  "partial":        ["points only some covered"],
  "unique":         ["insight only one panelist surfaced"],
  "blind_spots":    ["what none addressed but the task needs"]
}
```

### Step 6 — SYNTHESIS (you, Opus)

Write the final answer using the analysis: take consensus as the spine, resolve contradictions on
merits, fold in unique insights, cover blind spots yourself. This is the deliverable.

### Step 7 — Report

```
FUSION  [task]
Panel:   glm ✓ · deepseek ✓ · sonnet (skipped: sensitive)
Judge:   consensus N · contradictions N · unique N · blind_spots N

[Final synthesized answer]

Panel divergence worth noting:
- <model> uniquely flagged: ...
- contradiction resolved: ... because ...
```

## Notes

- **Judge is always Opus (this session).** Panelists never write files — you apply any code.
- Default panel = `glm` + `deepseek`. Enable `sonnet`/`opus` panel voices via `/fusion-config` if
  you want extra Claude-family diversity (note: judge is already Opus).
- Token cost: each panelist = one upstream call. Use the 1M panelists (`glm`, `deepseek`) for
  genuinely large context, not every trivial call.
- Context ceilings are enforced by the dispatcher (providers.json `max_context_tokens` /
  `tok_per_char`). Verified: glm 1,048,576 tok (~0.264 tok/char), deepseek 1,048,565 tok
  (~0.295 tok/char). Reasoning panelists get a `max_tokens` floor of 512 so reasoning doesn't
  starve the answer.
- Works whether or not `/fusion-on` is set — this command is the explicit, on-demand call.
