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

**Web search**: Add `--search` before the panelist name to enable Tavily-powered web search
(requires `TAVILY_API_KEY` in secrets.env). Panelists can request live web data via function
calling — useful for tasks involving current docs, pricing, or API references:
```bash
~/.claude/fusion/fusion-call --search deepseek <<'PROMPT'
<the shared panelist prompt>
PROMPT
```
Only the `openai` transport supports search today (DeepSeek via opencode-go). GLM (z.ai,
`anthropic` transport) and Codex (GPT-5.5) ignore the flag — use DeepSeek for search-enabled tasks.

Wait for all to return. Treat any `ERR:` line as that panelist abstaining (note it, continue).
Common `ERR:` causes: `timeout after Ns` (raise `CALL_TIMEOUT`), `prompt ~N tok exceeds …window`
(split/shrink context), `empty output (stop_reason=…)` (context exceeded), missing key.
Large 1M-context calls take ~40–60s — prefer `run_in_background: true` for those.

### Step 5 — JUDGE (you, Opus)

Compare the drafts. You MUST produce the analysis as a fenced JSON block FIRST:

```json
{
  "consensus": ["points all or most panelists agree on — treat as higher confidence"],
  "contradictions": [{"topic": "...", "stances": [{"model": "...", "stance": "..."}]}],
  "partial_coverage": [{"models": ["..."], "point": "only some models covered this"}],
  "unique_insights": [{"model": "...", "insight": "something only one model raised"}],
  "blind_spots": ["topics none addressed but the task needs"]
}
```

If any panelist returned ERR: or abstained, add:
```json
"failed_models": [{"model": "...", "reason": "timeout / empty / sensitive / etc"}]
```

CRITICAL: If you have web search or other tools available, USE THEM to verify uncertain claims
from panelists before judging. Do not trust panelist assertions blindly — cross-check against
documentation or live sources when claims are factual and verifiable.

After producing the JSON, proceed to synthesis (Step 6).

### Step 6 — SYNTHESIS (you, Opus)

Write the final answer using the analysis: take consensus as the spine, resolve contradictions on
merits, fold in unique insights, cover blind spots yourself. This is the deliverable.

### Step 7 — Report

```
FUSION  [task summary]

Panel:   glm ✓ (42s) · deepseek ✓ (38s) · sonnet (skipped: sensitive)
FUSION CONFIRMED: 2/3 panelists responded, 1 skipped

Judge:   consensus N · contradictions N · unique N · blind_spots N

[Final synthesized answer]

Panel divergence worth noting:
- <model> uniquely flagged: ...
- contradiction resolved: ... because ...
```

The "FUSION CONFIRMED: N/N panelists responded" line is MANDATORY. This prevents the
silent-single-model problem discovered by Steve Morin in OpenRouter Fusion testing.

If fewer than 2 panelists responded:
"WARNING: Only N panelist(s) responded — fusion quality degraded."

Count panelist responses: count fusion-call invocations that returned non-ERR: lines.
Compare against panelists dispatched in Step 4.

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
- **Fusion verification**: The report always shows "FUSION CONFIRMED: N/N panelists responded."
  This is CCF's guarantee that fusion actually ran — not a silent single-model fallback.
  (OpenRouter Fusion has a known issue where calls can quietly return single-model answers.)
- **Optional web search**: If TAVILY_API_KEY is set, run panelists with `--search` flag to enable
  web search tool calling. Panelists can request live web data via standard function calling.
- Works whether or not `/fusion-on` is set — this command is the explicit, on-demand call.
