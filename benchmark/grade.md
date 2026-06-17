# Grading Rubric — CCF Benchmark

Score each answer (solo Opus baseline **and** the `/fusion` panel answer) on a **0–100**
scale. The score is the weighted sum of four dimensions, each rated **0–10**:

| Dimension      | Weight | Multiplier | What it measures |
|----------------|:------:|:----------:|------------------|
| Correctness    | 40     | ×4         | Is the answer actually right? Does the code work / the advice hold up? |
| Completeness   | 25     | ×2.5       | Did it address every part of the task, or skip requirements? |
| Blind spots    | 20     | ×2         | Did it surface non-obvious risks, edge cases, and second-order effects? |
| Code quality   | 15     | ×1.5       | Readable, idiomatic, tested, maintainable (N/A weighting for prose answers) |

**Formula:**

```
score = (correctness × 4) + (completeness × 2.5) + (blind_spots × 2) + (code_quality × 1.5)
```

Each dimension is 0–10, so the maximum is `10×4 + 10×2.5 + 10×2 + 10×1.5 = 100`.

## 0–10 anchors (apply to every dimension)

| Points | Meaning |
|:------:|---------|
| **9–10** | Excellent — fully correct, thorough, surfaces subtle issues a reviewer would miss. Production-ready. |
| **7–8**  | Good — solves the task well with minor gaps or one missed edge case. |
| **5–6**  | Adequate — works for the happy path but misses something material (an edge case, a requirement). |
| **3–4**  | Weak — partial / superficial; notable errors or omissions. |
| **1–2**  | Mostly wrong or largely incomplete. |
| **0**    | Missing, irrelevant, or dangerously incorrect. |

## Per-dimension guidance

- **Correctness** — For code tasks: does it compile/run and produce the right result on the
  intended inputs, including the planted bug? For design tasks: are the technical claims true
  (ordering guarantees, durability semantics, throughput numbers)?
- **Completeness** — Did it fix *both* bugs (not just the obvious one)? Address every
  numbered requirement? Provide the requested artifacts (code, tests, explanation)?
- **Blind spots** — The discriminating dimension. Did it flag: security implications, data
  races, failure modes, scaling cliffs, operational cost, migration risk? Answers that only
  solve the stated problem score low here; answers that anticipate what *wasn't* asked score
  high.
- **Code quality** — Naming, structure, idioms for the language, error handling, test
  coverage. For pure-prose tasks (e.g. architecture), weight this toward clarity and
  precision of argument instead.

## How to compare solo vs. fusion

1. Run `benchmark/run.sh` to produce both answers per task (solo baseline in `results/solo/`,
   fusion in `results/fusion/`).
2. Grade **both** with this rubric, blind to which is which if possible.
3. Record `Δ = fusion − solo` per task in `README.md`'s results table.
4. The value of the panel shows up most in **blind spots** and **completeness** — a second
   independent draft catches what one model misses. If fusion wins mainly on correctness,
   the panel is catching outright errors; if it wins on blind spots, it's adding perspective.
