# CCF Benchmark — Solo vs Fusion

A reproducible benchmark for **Claude Code Fusion**: does a multi-model fusion
panel (panel → judge → synthesis) beat a solo orchestrator on realistic
software-engineering tasks?

## Design — Fair Comparison

The benchmark has **two arms**, both run by the same AI orchestrator:

| Arm | What happens | Who produces the answer |
|-----|-------------|------------------------|
| **SOLO** | Orchestrator reads the task and answers directly | Orchestrator alone |
| **FUSION** | Orchestrator calls panelists sequentially → judges → synthesizes | Panelists + orchestrator judgment |

**Why this is fair:** Same orchestrator intelligence, same task. The only
variable is whether diverse panelists feed additional perspectives.

**Critical requirement:** For a valid test, the orchestrator/judge must be a
**different model family** from at least some panelists. If the orchestrator
is the same model as a panelist (e.g., GLM orchestrator + GLM panelist), the
test is biased — the judge already agrees with itself.

### Ideal real-world setup

| Role | Model | Why |
|------|-------|-----|
| Orchestrator/Judge | **Opus** (Claude Max subscription) | Strongest reasoning for judgment |
| Panelist 1 | **GLM-5.2** (z.ai) | Different training data, 1M context |
| Panelist 2 | **DeepSeek** (OpenCode-Go) | Different strengths in code/security |
| Panelist 3 | **GPT-5.5** (Codex subscription) | Third independent perspective |

This ensures true model diversity in both the panel and the judge.

## Tasks

| File | Domain | Planted difficulty |
|------|--------|--------------------|
| `tasks/01-bug-fix.md` | Python | Off-by-one **and** hidden type-coercion bug |
| `tasks/02-security.md` | Node.js API | SQL injection **and** timing attack |
| `tasks/03-refactor.md` | Python | ~200-line god function needing modular split |
| `tasks/04-architecture.md` | System design | Redis vs Kafka vs RabbitMQ for 10K chat |
| `tasks/05-concurrency.md` | Go | Goroutine data race |

## How to Run

### Option A — Slash commands (recommended, in Claude Code)

```
/fusion-benchmark              # all 5 tasks, solo + fusion, sequential
/fusion-benchmark 01           # just task 01
/fusion-benchmark 01 03 05     # selected tasks
```

Then generate the report:

```
/fusion-benchmark-report
```

The orchestrator does everything: solo answers, panelist calls, judgment,
synthesis, and grading. Output goes to `benchmark/results/`.

### Option B — Standalone bash runner (data collection only)

```bash
benchmark/run-benchmark.sh            # collect all tasks, all panelists
benchmark/run-benchmark.sh 01         # just task 01
benchmark/run-benchmark.sh --list     # show tasks + enabled panelists
```

This collects raw panelist responses **without judgment**. Use it when you
want to separate data collection from analysis. After collecting, run
`/fusion-benchmark-report` to judge and grade.

## Methodology

1. **Same prompt, no hints.** Each task file is the entire prompt. Neither
   solo nor fusion gets extra coaching.
2. **Sequential execution.** Panelists are called one at a time, never in
   parallel. This respects rate limits and ensures consistent timing.
3. **Identical prompt to all panelists.** The exact task file content is
   sent to every panelist. No rephrasing, no bias.
4. **Blind grading.** Score both answers with `grade.md` (0–100, four
   weighted dimensions). Grade the synthesized answer, not raw panelist text.
5. **Record Δ.** `fusion − solo` per task. Positive Δ on *blind spots* and
   *completeness* is the signal that the panel adds value.

## Output Files

```
benchmark/results/
├── solo-01.md              # Orchestrator's solo answer for task 01
├── solo-02.md
├── ...
├── fusion-01.md            # Full fusion output (panel + judgment + synthesis)
├── fusion-02.md
├── ...
├── raw-01-glm.md           # Raw panelist responses (from bash runner)
├── raw-01-deepseek.md
├── ...
└── REPORT.md               # Final comparison report
```

## Grading

See `grade.md` for the full rubric. Summary:

| Dimension | Weight | What it measures |
|-----------|:------:|------------------|
| Correctness | 40% | Is the answer actually right? |
| Completeness | 25% | Did it address every part? |
| Blind spots | 20% | Did it surface non-obvious risks? |
| Code quality | 15% | Readable, idiomatic, tested? |

## Results

> Empty until you run the benchmark. Fill from REPORT.md.

| Task | Solo (0-100) | Fusion (0-100) | Δ | Notes |
|------|:---:|:---:|:---:|-------|
| 01-bug-fix | | | | |
| 02-security | | | | |
| 03-refactor | | | | |
| 04-architecture | | | | |
| 05-concurrency | | | | |
| **Average** | | | | |
