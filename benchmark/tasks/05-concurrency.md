# Task 05 — Concurrency: Go Goroutine Race Condition

## Context

A metrics service fan-outs a batch of HTTP fetches across goroutines and aggregates the
results into a shared map. It works fine under light load in dev, but in production it
**occasionally panics** (`fatal error: concurrent map writes`), returns **wrong totals**, and
once corrupted a counter so that it went **negative**. Restarting "fixes" it until it happens
again.

```go
package main

import (
	"fmt"
	"sync"
)

type Aggregator struct {
	mu       sync.Mutex
	counts   map[string]int
	totals   map[string]float64
}

func NewAggregator() *Aggregator {
	return &Aggregator{
		counts: make(map[string]int),
		totals: make(map[string]float64),
	}
}

// Record is meant to be safe to call from many goroutines.
func (a *Aggregator) Record(source string, value float64) {
	a.counts[source]++          // count per source
	a.totals[source] += value   // sum per source
}

func (a *Aggregator) Snapshot() map[string]float64 {
	a.mu.Lock()
	defer a.mu.Unlock()
	out := make(map[string]float64, len(a.totals))
	for k := range a.totals {
		out[k] = a.totals[k] / float64(a.counts[k]) // average per source
	}
	return out
}

func main() {
	a := NewAggregator()
	sources := []string{"alpha", "beta", "gamma"}

	var wg sync.WaitGroup
	for i := 0; i < 1000; i++ {
		for _, s := range sources {
			wg.Add(1)
			go func(s string) {
				defer wg.Done()
				a.Record(s, 1.0)
			}(s)
		}
	}
	wg.Wait()

	fmt.Println(a.Snapshot())
}
```

## Task

1. **Identify every concurrency defect.** There is a blatant one and a subtler one. Explain
  precisely *why* each is a race, what Go's memory model / race detector says about it, and
  what symptoms each produces (the panic, the wrong totals, the negative counter).
2. **Fix it correctly**, in at least two idiomatic ways and justify when you'd pick each:
  - (a) mutex-guarded map (fix the locking — note the lock is *declared* but never used in
    `Record`),
  - (b) per-goroutine local accumulation merged back via a channel or `sync/atomic`-backed
    counter.
3. **Verify** the fix: how would you run the race detector (`go run -race`), and what test
  would prove the totals are now consistent across goroutines (e.g. total count == 3000,
  per-source average == 1.0)?

## Grading criteria (0–10 each)

- **Correctness** — Both defects fixed; maps are never written concurrently; `Record` and
  `Snapshot` are mutually safe; totals come out correct and deterministic. The detector is
  clean.
- **Completeness** — Both fixes provided (mutex + channel/atomic) with the trade-off
  explained; a real test that would fail before and pass after; race-detector usage stated.
- **Blind spots** — Did it catch that the **declared `sync.Mutex` is never locked in
  `Record`** (the obvious bug) **and** that the *map write itself* is the race (the subtler
  point — it's not just "forgot the lock", it's that map writes aren't concurrency-safe in
  Go at all)? Did it note the read in `Snapshot` racing writes, the lock-copy risk if
  `Aggregator` were passed by value, and the difference between guarding the whole struct vs
  finer-grained locking? Did it mention `go test -race` as a permanent CI guard?
- **Code quality** — Idiomatic Go (don't lock in a defer unnecessarily; pick the right
  primitive), clear comments on the memory model, a clean runnable test, no deadlocks.
