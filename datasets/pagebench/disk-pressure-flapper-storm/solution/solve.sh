#!/bin/bash
# Oracle solution: write the known-correct triage decisions for disk-pressure-flapper-storm.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "Real KubeNodePressure: DiskPressure=True on node ip-10-0-3-21.us-east-1.compute.internal, never auto-resolved, pat-diskpressure-evict is a surging negative pattern with active pod-eviction risk for play-svc. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on http-receiver: 18 fires/hr, self-clears in ~20s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on transformer: 21 fires/hr, self-clears in ~17s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on platform-api: 19 fires/hr, self-clears in ~22s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on kafka-metric-ingestor: 17 fires/hr, self-clears in ~15s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-compactor marginally over 80% threshold, self-resolved in 35s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-compactor marginally over 80% threshold, self-resolved in 41s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Disk-usage warning on olapdb-server marginally over 80% threshold, self-resolved in 28s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "Disk-usage warning on olapdb-server marginally over 80% threshold, self-resolved in 33s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Disk-usage warning on dashboard-svc marginally over 80% threshold, self-resolved in 19s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on auditlog-ingestor: 16 fires/hr, self-clears in ~18s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on workflow-engine: 20 fires/hr, self-clears in ~21s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-agent-v1 marginally over 80% threshold, self-resolved in 30s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-agent-v1 marginally over 80% threshold, self-resolved in 24s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on olapdb-tso: 15 fires/hr, self-clears in ~16s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "Disk-usage warning on dashboard-worker marginally over 80% threshold, self-resolved in 22s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "Disk-usage warning on http-receiver marginally over 80% threshold, self-resolved in 27s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on transformer: 18 fires/hr, self-clears in ~19s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "[ignore]-prefixed Default Log Threshold Monitor on log-compactor: 17 fires/hr, self-clears in ~20s, pat-log-threshold is flat/neutral. Canonical flapper noise by design."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "Disk-usage warning on olapdb-vw-default marginally over 80% threshold, self-resolved in 38s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-diskpressure-evict root): kube-state-metrics scrape failures on the same pressured node. Collapse into the eviction incident; do not page separately."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "Disk-usage warning on kafka-metric-ingestor marginally over 80% threshold, self-resolved in 26s on log rotation/compaction. Not the pressured eviction node; returns to baseline."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — disk-pressure-flapper-storm

The single real, must-page incident is **P01**: DiskPressure=True on node ip-10-0-3-21.us-east-1.compute.internal with active pod-eviction risk for play-svc (matches the recurring real disk-pressure incidents). P21 is a downstream symptom (kube-state-metrics scrape failures on the same node) and collapses into P01. Everything else is the chronic `[ignore] Default Log Threshold Monitor` flapping and disk-usage warnings that self-resolve on rotation/compaction.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
