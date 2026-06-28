#!/bin/bash
# Oracle solution: write the known-correct triage decisions for queue-backlog-vs-blip.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "metric-ingest-queue-1 oldest-message age 1048s vs 300s, rising 810->1048->1290->1610 and never auto-resolving; pat-queue-stalled +980% negative. Sustained backlog, root incident."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "metric-ingestor-large queue age 360 vs 300, auto-resolved in 70s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "metric-ingestor-large queue_depth 5400 vs 5000, auto-resolved in 55s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "kafka-metric-ingestor queue age 340 vs 300, auto-resolved in 48s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "auditlog-ingestor queue_depth 5200 vs 5000, auto-resolved in 62s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "kafka-metric-ingestor queue age 315 vs 300, auto-resolved in 44s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "metric-ingestor-large queue age 370 vs 300, auto-resolved in 66s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "auditlog-ingestor queue age 330 vs 300, auto-resolved in 58s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "kafka-metric-ingestor queue_depth 5300 vs 5000, auto-resolved in 51s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "metric-ingestor-large queue_depth 5150 vs 5000, auto-resolved in 49s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on olapdb-tso, 18 fires/hr, auto-resolved in 19s, pat-log-threshold delta 0. Chronic flapper."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on transformer, 20 fires/hr, auto-resolved in 22s, pat-log-threshold delta 0. Chronic flapper."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "auditlog-ingestor queue age 320 vs 300, auto-resolved in 53s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "kafka-metric-ingestor queue_depth 5250 vs 5000, auto-resolved in 47s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "metric-ingestor-large queue age 350 vs 300, auto-resolved in 60s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on olapdb-server, 16 fires/hr, auto-resolved in 18s, pat-log-threshold delta 0. Chronic flapper."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "auditlog-ingestor queue_depth 5180 vs 5000, auto-resolved in 56s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "kafka-metric-ingestor queue age 310 vs 300, auto-resolved in 42s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "olapdb-vw-write 5xx, same pat-queue-stalled root and onset window as P01 (write path blocked by the stalled queue). Correlated symptom; collapse into P01."
    },
    {
      "page_id": "P20",
      "decision": "page",
      "reason": "metric-dlq-redrive-1 dlq_depth 2200 vs 500, rising 40->2200->6400->9100 and never auto-resolving; pat-consumer-crashloop +1700% negative, correlated to enrich-2026.06.20-c. DLQ fill from a crashlooping consumer, root incident."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "enrichment-consumer pod_restart_count 37 vs 5, same pat-consumer-crashloop root and enrich-2026.06.20-c deploy as P20. Correlated symptom; collapse into P20."
    },
    {
      "page_id": "P22",
      "decision": "page",
      "reason": "kafka-trace-consumer consumer_lag_records 1.85M vs 200k, climbing 95k->1.85M->3.2M->4.9M and never auto-resolving; pat-consumer-lag-sustained +540% negative, no deploy to blame. Quiet but real sustained SLO breach."
    },
    {
      "page_id": "P23",
      "decision": "suppress",
      "reason": "kafka-trace-consumer lag 240k vs 200k, auto-resolved in 38s (lag fell 240k->98k), 6 fires/hr, pat-queue-blip flat/neutral. Self-draining lag blip on the same service as P22, but it recovered."
    },
    {
      "page_id": "P24",
      "decision": "suppress",
      "reason": "metric-ingestor-large queue age 345 vs 300, auto-resolved in 57s, pat-queue-blip flat/neutral. Self-draining blip."
    },
    {
      "page_id": "P25",
      "decision": "page",
      "reason": "spanmetrics-rollup-consumer queue_depth 12400 vs 5000. Looks like a flapper (16 fires/hr, auto-resolves in 47s), but the metrics.csv trough ratchets up every cycle: drains to 2050, then 5100, then 12050, then 15700, never back to the 210 baseline. pat-rollup-queue-ratchet +260% negative. A saturating consumer, not noise."
    },
    {
      "page_id": "P26",
      "decision": "suppress",
      "reason": "kafka-event-archiver consumer_lag_records 2.6M vs 200k, no auto-resolve, SEV2 — but archiver-backfill-2026.06.20-b (kind backfill-job, window 08:00-10:00, expected peak 3.0M, drain 40k/min) explains it, and the lag plateaus at 2.65M (under the 3.0M envelope) then drains 2.65M->2.10M->1.18M, well within the configured replay rate. Expected backfill steady-state."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — queue-backlog-vs-blip

Four independent real incidents must wake a human; everything else is self-draining noise or a correlated symptom.

- **P01 (page, root):** metric-ingest-queue-1 oldest-message age rising 810->1048->1290->1610s and never recovering, pat-queue-stalled surging +980% negative. **P19** (olapdb-vw-write 5xx) is the same pat-queue-stalled root at the same onset — a downstream symptom of the stalled queue, suppressed as a duplicate of P01.
- **P20 (page, root):** metric-dlq-redrive-1 DLQ depth rising 40->2200->6400->9100 and never draining, pat-consumer-crashloop +1700% negative, correlated to the enrich-2026.06.20-c deploy. **P21** (enrichment-consumer pod_restart_count 37) shares the same crashloop root + deploy and is suppressed as a symptom of P20.
- **P22 (page, root):** kafka-trace-consumer consumer lag climbing 95k->1.85M->3.2M->4.9M, never auto-resolving, pat-consumer-lag-sustained +540% negative, with no deploy to blame. A quiet, slow-rising but genuine SLO breach. **P23** is the look-alike decoy: same service + metric, but a 240k blip that drained back to 98k in 38s (pat-queue-blip) — suppress.
- **P25 (page, root):** spanmetrics-rollup-consumer queue_depth presents like a flapper (16 fires/hr, auto-resolves in 47s) but the metrics.csv floor ratchets up every cycle — drains to 2050, then 5100, then 12050, then 15700, never back to the 210 baseline. pat-rollup-queue-ratchet +260% negative with shrinking flush batches. A slowly-saturating consumer; the high fired_count + short auto-resolve are misleading. **P26** is the inverse: kafka-event-archiver lag 2.6M with no auto-resolve and SEV2 looks like a real breach, but archiver-backfill-2026.06.20-b (backfill-job, expected peak 3.0M, drain 40k/min) explains it and the lag plateaus at 2.65M then drains 2.65M->2.10M->1.18M within the configured replay envelope — suppress.

All remaining queue alerts (P02-P18 minus P11/P12/P16, plus P24) are pat-queue-blip: marginally over threshold and auto-resolved within ~40-70s. P11/P12/P16 are [ignore] log-threshold flappers. See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
