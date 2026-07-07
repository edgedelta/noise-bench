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
      "reason": "DiskPressure=True on node ip-10-0-3-21, node_disk_used_pct 71->97 and holding, never auto-resolved, pat-diskpressure-evict surging 9x negative with active pod-eviction risk for play-svc. SEV1 cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on http-receiver: 18 fires/hr, self-clears in ~20s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on transformer: 21 fires/hr, self-clears in ~17s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on platform-api: 19 fires/hr, self-clears in ~22s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on kafka-metric-ingestor: 17 fires/hr, self-clears in ~15s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-compactor marginally over 80%; rotation returned the metric below threshold within a minute (78 by 14:11) but the monitor has no auto-clear, so the alert latched open. Recovered metric, stale alert."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-compactor marginally over 80%, self-resolved in 41s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Disk-usage warning on olapdb-server marginally over 80%, self-resolved in 28s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "Disk-usage warning on olapdb-server marginally over 80%, self-resolved in 33s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Disk-usage warning on dashboard-svc marginally over 80%, self-resolved in 19s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on auditlog-ingestor: 16 fires/hr, self-clears in ~18s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on workflow-engine: 20 fires/hr, self-clears in ~21s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-agent-v1 marginally over 80%, self-resolved in 30s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Disk-usage warning on log-agent-v1 marginally over 80%, self-resolved in 24s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on olapdb-tso: 15 fires/hr, self-clears in ~16s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "Disk-usage warning on dashboard-worker marginally over 80%, self-resolved in 22s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "Disk-usage warning on http-receiver marginally over 80%, self-resolved in 27s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on transformer: 18 fires/hr, self-clears in ~19s, pat-log-threshold flat/neutral. Flapper noise."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor on log-compactor mis-routed to SEV1: 17 fires/hr, self-clears in ~20s, pat-log-threshold flat/neutral. Wrong severity tag on the canonical flapper."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "Disk-usage warning on olapdb-vw-default marginally over 80%, self-resolved in 38s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (shares pat-diskpressure-evict root): kube-state-metrics scrape failures on the same node ip-10-0-3-21. Collapse into the P01 eviction incident."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "Disk-usage warning on kafka-metric-ingestor marginally over 80%, self-resolved in 26s on rotation/compaction. Returns to baseline."
    },
    {
      "page_id": "P23",
      "decision": "page",
      "reason": "DiskPressure=True on a second node ip-10-0-7-88, node_disk_used_pct 74->99 and holding, never auto-resolved, pat-diskpressure-evict-7-88 surging 7.4x negative with kubelet already evicting ingest-router pods. Independent SEV1 from a different node than P01. Must-page."
    },
    {
      "page_id": "P24",
      "decision": "page",
      "reason": "PVC clickhouse-keeper-data-0 at 100% (pvc_used_pct 86->100 and pinned), never auto-resolved, pat-pvc-full-writefail negative with active write failures on a stateful service. Must-page despite the flat pattern delta and the monitor-default SEV3 tag."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — disk-pressure-flapper-storm

Three independent real incidents must page:

- **P01** — DiskPressure=True on node ip-10-0-3-21, never auto-resolved, surging negative
  pattern, active pod-eviction risk for play-svc.
- **P23** — DiskPressure=True on a *second* node ip-10-0-7-88 (different node/root from P01),
  kubelet already evicting ingest-router pods, never auto-resolved.
- **P24** — clickhouse-keeper PVC pinned at 100% with active write failures on a stateful
  service; it looks quiet twice over (flat pattern delta, monitor-default SEV3 tag) but
  pvc_used_pct is at full and never auto-resolves.

**P21** is the downstream kube-state-metrics scrape-failure symptom of P01 (same
pat-diskpressure-evict root on the same node) and collapses into P01 — suppress as a duplicate.

Everything else is the chronic `[ignore] Default Log Threshold Monitor` flapping (high
fired_count_last_1h, sub-30s auto_resolved — including P19, which a mis-routed paging rule
tags SEV1) or disk-usage warnings that return to baseline on rotation/compaction. P06's
alert latched open (no auto-clear on the synthetic monitor) but metrics.csv shows the disk
back under threshold a minute later — a stale alert, not an incident.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
