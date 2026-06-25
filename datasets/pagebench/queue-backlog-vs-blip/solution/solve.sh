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
      "reason": "Real sustained backlog: metric-ingest-queue-1 oldest-message age 1048s vs 300s, rising (810s->1048s) and NEVER draining, with pat-queue-stalled surging negative (SQS ack failures + downstream write 500s). This is the genuine queue-backlog incident, not a blip. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "Transient queue blip on metric-ingestor-large (queue_oldest_msg_age_s marginally over threshold), drained on its own in 70s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "Transient queue blip on metric-ingestor-large (queue_depth marginally over threshold), drained on its own in 55s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Transient queue blip on kafka-metric-ingestor (queue_oldest_msg_age_s marginally over threshold), drained on its own in 48s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "Transient queue blip on auditlog-ingestor (queue_depth marginally over threshold), drained on its own in 62s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Transient queue blip on kafka-metric-ingestor (queue_oldest_msg_age_s marginally over threshold), drained on its own in 44s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Transient queue blip on metric-ingestor-large (queue_oldest_msg_age_s marginally over threshold), drained on its own in 66s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Transient queue blip on auditlog-ingestor (queue_oldest_msg_age_s marginally over threshold), drained on its own in 58s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "Transient queue blip on kafka-metric-ingestor (queue_depth marginally over threshold), drained on its own in 51s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Transient queue blip on metric-ingestor-large (queue_depth marginally over threshold), drained on its own in 49s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper on olapdb-tso: 18 fires/hr, self-clears in 19s. Noise."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper on transformer: 20 fires/hr, self-clears in 22s. Noise."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Transient queue blip on auditlog-ingestor (queue_oldest_msg_age_s marginally over threshold), drained on its own in 53s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Transient queue blip on kafka-metric-ingestor (queue_depth marginally over threshold), drained on its own in 47s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "Transient queue blip on metric-ingestor-large (queue_oldest_msg_age_s marginally over threshold), drained on its own in 60s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper on olapdb-server: 16 fires/hr, self-clears in 18s. Noise."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "Transient queue blip on auditlog-ingestor (queue_depth marginally over threshold), drained on its own in 56s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "Transient queue blip on kafka-metric-ingestor (queue_oldest_msg_age_s marginally over threshold), drained on its own in 42s (pat-queue-blip flat/neutral, returns to baseline). Not a sustained backlog. Noise."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-queue-stalled root): olapdb-vw-write 500s as the stalled queue blocks the write path. Collapse into the backlog incident."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-queue-stalled root): DLQ depth growing on metric-dlq-1 as messages fail to drain. Collapse into the backlog incident."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — queue-backlog-vs-blip

The single real, must-page incident is **P01**: a sustained, non-draining backlog on metric-ingest-queue-1 — oldest-message age rising 810s->1048s->1290s and never recovering, pat-queue-stalled surging negative (SQS ack failures + commitParts timeouts). P19 (olapdb-vw-write 500s) and P20 (DLQ depth growing) are downstream symptoms of the same stalled queue and collapse into P01. Every other queue alert is a transient blip that drained on its own within ~60s (pat-queue-blip, returns to baseline) plus [ignore] log flappers.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
