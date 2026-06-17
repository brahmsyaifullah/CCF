# Task 04 — Architecture: Messaging Backbone for 10K Concurrent Chat

## Context

You are designing the real-time messaging backbone for a consumer chat product. Requirements
(supplied by product):

- **~10,000 concurrent connected users** at peak today, expected to **10× within a year**.
- **Direct messages and small group chats** (up to ~50 participants). Messages should arrive
  in **order** within a conversation and be **delivered at most once** to online clients; a
  short, bounded amount of reordering/duplication on reconnect is acceptable.
- **Offline delivery**: if a user is away, their messages must be buffered and pushed on
  reconnect. Retention horizon: **30 days**.
- Messages must be **persisted** (audit/compliance), but per-message **exactly-once** end-to-end
  is explicitly *not* required.
- Presence ("who's online") and typing indicators are nice-to-have but must not block core
  delivery.
- The team is small; **operational simplicity** matters. Budget exists but is watched.

The team is debating three options and wants you to settle it: **Redis (Pub/Sub + Streams),
Apache Kafka, or RabbitMQ.**

## Task

Produce an architecture decision write-up:

1. **Recommend one** primary backbone (you may combine — e.g. Redis for presence + Kafka for
  the log — but justify the split). State your recommendation up front.
2. **Compare the three** on the dimensions that actually matter for this workload:
  delivery semantics (at-most/at-least/exactly-once), ordering guarantees (per-partition vs
  global vs none), fan-out model (topic/queue/stream), durability/retention, throughput at
  this scale, operational complexity, and cost model.
3. **Design the data flow** end-to-end: connection handling, how a message is published,
  fanned out to N recipients, buffered for offline users, and persisted. Note where
  partitioning/affinity lives (so a conversation's messages stay ordered).
4. Call out the **failure modes and limits** of your chosen design: what breaks first at
  100K users, where you'd shard, and what you'd *not* use each system for.

## Grading criteria (0–10 each)

- **Correctness** — Technical claims are accurate: Kafka partition ordering vs global,
  consumer-group semantics; Redis Streams vs Pub/Sub (Pub/Sub fire-and-forget, Streams
  persistent); RabbitMQ queue/exchange models and ACK semantics; at-least-once vs
  exactly-once trade-offs. No factually wrong statements.
- **Completeness** — Addresses all three options, all numbered requirements (concurrency,
  ordering, offline/retention, persistence, presence), and the end-to-end data flow. A clear,
  up-front recommendation.
- **Blind spots** — Did it consider: ordering requires **per-conversation partition
  affinity** (random partitioning breaks order)? Redis Pub/Sub loses messages to offline
  subscribers (needs Streams/backup)? Kafka's retention ≠ a user inbox (you still need a
  per-user mailbox/sequence)? Backpressure and slow-consumer handling? The cost/ops burden of
  running Kafka vs managed? WebSockets/connection layer vs the broker? Did it avoid the trap
  of "Kafka for everything"?
- **Code quality** *(prose task — weighted toward clarity)* — Well-structured, concrete,
  uses real numbers/limits, distinguishes "good enough now" from "scales to 100K", and gives
  actionable trade-offs rather than vendor marketing.
