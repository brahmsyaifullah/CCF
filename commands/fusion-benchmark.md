---
description: Run the CCF benchmark — SOLO (you answer directly) vs FUSION (panel → you judge). Tasks run sequentially; panelists within a task run in parallel. Outputs markdown files.
---

# /fusion-benchmark — Solo vs Fusion Controlled Experiment

Does a multi-model fusion panel beat a solo orchestrator on realistic
software-engineering tasks? **You are both arms of the experiment.**

- **SOLO**: You answer the task yourself. No panelists called. Your raw reasoning.
- **FUSION**: You call all panelists **in parallel** for the task, collect their
  answers, then judge + synthesize. Your value-add is the judgment.

This design is fair: same orchestrator intelligence, same task, the only
variable is whether diverse panelists feed you additional perspectives.

## Arguments

```
/fusion-benchmark              # all 5 tasks, solo + fusion
/fusion-benchmark 01           # just task 01
/fusion-benchmark 01 03 05     # tasks 01, 03, 05
```

## Prerequisites

1. CCF installed (`/fusion-status` passes)
2. At least 2 panelists enabled in `panel.json` (fusion needs diversity)
3. `benchmark/tasks/` exists with task files

## Setup

```bash
mkdir -p benchmark/results
# List enabled panelists — you'll call each one in FUSION phase
jq -r '.panel[] | select(.enabled) | "\(.name) (\(.provider)/\(.model))"' ~/.claude/fusion/panel.json
```

Note the panelist names. If fewer than 2 are enabled, warn the user and stop.

## Execution — TASKS SEQUENTIAL, PANELISTS PARALLEL

Process each task fully (SOLO then FUSION) before moving to the next task —
**one task at a time, never overlap tasks.** *Within* a task's FUSION phase,
call all panelists **at the same time** (parallel) and wait for the whole batch.

---

### Phase 1 — SOLO (you answer directly)

1. Read the task file: `benchmark/tasks/XX-*.md`
2. Answer the task yourself using your full reasoning capability.
   - Do NOT call any panelists.
   - Do NOT use `/fusion`.
   - You MAY reason through the code, but the answer is YOUR work alone.
3. Save your answer to a file:

```bash
cat > benchmark/results/solo-XX.md << 'BENCH_EOF'
# SOLO — Task XX — <task name>

> Model: <your model identifier>
> Timestamp: <ISO 8601>
> Mode: Solo (orchestrator only, no panel)

<your complete answer>

BENCH_EOF
```

4. Record approximate time spent.

---

### Phase 2 — FUSION (panel → you judge)

1. Read the SAME task file again (approach it fresh).
2. Extract the task prompt — the **exact** content of the task file.
3. Call ALL enabled panelists **in parallel** for this task (one shared prompt),
   then wait for the whole batch before judging. Launch them with multiple Bash
   calls in a single message, or background them and `wait`:

```bash
# Read the task into a variable so every panelist gets the identical prompt
PROMPT=$(cat benchmark/tasks/XX-*.md)

# Launch every enabled panelist concurrently, each to its own file.
~/.claude/fusion/fusion-call <panelist1> "$PROMPT" > benchmark/results/raw-XX-<panelist1>.md 2>&1 &
~/.claude/fusion/fusion-call <panelist2> "$PROMPT" > benchmark/results/raw-XX-<panelist2>.md 2>&1 &
~/.claude/fusion/fusion-call <panelist3> "$PROMPT" > benchmark/results/raw-XX-<panelist3>.md 2>&1 &
wait    # block until ALL panelists for THIS task finish
```

Or just run `benchmark/run-benchmark.sh XX` (does the parallel-per-task collection for you).

**If a panelist fails** (timeout, error, empty response): note the error,
mark it as failed, and continue with the remaining panelists. Record
`FUSION CONFIRMED: N/M` where M = total attempted.

4. **JUDGE** all panelist responses. Produce structured analysis:

   - **CONSENSUS** — findings ALL successful panelists agree on (high confidence)
   - **UNIQUE INSIGHTS** — findings only ONE panelist caught (per panelist)
   - **BLIND SPOTS** — things ALL panelists missed that YOU can identify
   - **FUSION CONFIRMED: N/N** — successful responses / total attempted

5. **SYNTHESIZE** the final answer — the union of all insights, deduplicated,
   re-ranked by severity/importance, with your own additions for blind spots.

6. Save the complete fusion output:

```bash
cat > benchmark/results/fusion-XX.md << 'BENCH_EOF'
# FUSION — Task XX — <task name>

> Judge: <your model identifier>
> Panel: <panelist1 (model1)>, <panelist2 (model2)>, ...
> Timestamp: <ISO 8601>
> Mode: Fusion (panel → judge → synthesis)

## Panelist Responses

### <Panelist1> (<model1>)

<full raw response>

### <Panelist2> (<model2>)

<full raw response>

## Judgment

### Consensus
- ...

### Unique Insights
- **<Panelist1>**: ...
- **<Panelist2>**: ...

### Blind Spots (judge adds)
- ...

**FUSION CONFIRMED: N/N**

## Final Synthesized Answer

<the merged, deduplicated, re-ranked answer>

BENCH_EOF
```

---

### Between tasks

Wait 5 seconds before starting the next task (rate-limit courtesy).

## After all tasks

Tell the user the benchmark is complete and suggest running
`/fusion-benchmark-report` to generate the comparison report.

## Rules

- **Tasks sequential, panelists parallel.** Never overlap two *tasks*. Within a task,
  run all panelists at once and `wait` for the batch before judging.
- **SOLO = your work alone.** No panelist calls, no `/fusion`.
- **FUSION = your judgment IS the product.** Be rigorous and honest.
- **Same prompt to all panelists.** Use the exact task file content.
- If you hit a rate limit: STOP, tell the user, don't retry aggressively.
- Save EVERYTHING as markdown in `benchmark/results/`.
