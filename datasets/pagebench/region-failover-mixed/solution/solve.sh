#!/bin/bash
# Oracle solution: write the known-correct triage decisions for region-failover-mixed.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "suppress",
      "reason": "edge-lb us-west 503 spike at the 03:00 cutover, 9 fires/hr, cleared in 38s; metric 0.21 -> 0.005 within two minutes. DNS re-resolution churn from the traffic shift."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "checkout connection-reset spike during the shift, 11 fires/hr, cleared in 29s; 0.18 -> 0.04. Expected reconnect churn, recovered."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "orders connection-reset spike, same pat-failover-conn-reset, cleared in 31s; 0.15 -> 0.03. Reconnect churn."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "recommendation-uswest cold-cache latency on warming replicas, cleared in 52s; p99 1450 -> 610. Warmup transient."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "search-uswest cold-cache latency, same pat-coldstart-cache, cleared in 44s; p99 1290 -> 540. Warmup transient."
    },
    {
      "page_id": "P06",
      "decision": "page",
      "reason": "payments-api-uswest request_queue_depth 48000 vs 8000, never auto-resolved, climbs 1200 -> 48000 -> 88000 with no drain; pat-uswest-saturation 17x, negative. Target-region service overloaded by the shifted traffic and NOT recovering. SEV1 root."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "checkout 5xx sustained (0.27 -> 0.34) sharing pat-uswest-saturation, ~100s after P06. Downstream symptom of the payments-api saturation; collapse into P06."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "orders p99 sustained (7600 -> 8900) sharing pat-uswest-saturation, within ~150s of P06. Downstream symptom; duplicate of P06."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "ingest-gateway JVM warmup GC, cleared in 33s; cpu 94 -> 47. Warmup transient on freshly scheduled pods."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "profile-svc-uswest JVM warmup GC, same pat-jvm-warmup-gc, cleared in 27s; cpu 92 -> 51. Warmup transient."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "edge-lb healthcheck flap, 14 fires/hr, cleared in 21s; 0.33 -> 0.05. Backend rotated healthy as pods came up."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "edge-lb healthcheck flap again, same pat-lb-healthcheck-flap, 14 fires/hr, cleared in 19s. Same flapper as P11."
    },
    {
      "page_id": "P13",
      "decision": "page",
      "reason": "postgres-replica-uswest replication_lag_s 640 vs 60, never auto-resolved, climbs 3 -> 640 -> 1180 and rising; pat-xregion-replica-lag ~10x, negative. Cross-region replication breach that persists. SEV1 root."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "reporting stale_read_rate sustained (0.61 -> 0.66) sharing pat-xregion-replica-lag, ~3min after P13. Downstream symptom; collapse into P13."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "cdn-edge origin 503 at the cutover, same pat-failover-dns-reresolve, cleared in 41s. DNS re-resolution churn."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "notifications queue catch-up after consumer reconnect, cleared in 36s; 6200 -> 4100. Drain catch-up transient."
    },
    {
      "page_id": "P17",
      "decision": "page",
      "reason": "audit-log-store disk rising monotonically 86 -> 88 -> 90 -> 91 -> 93 since 02:30 (before cutover), never auto-resolved, no deploy/failover correlation. Quiet slow-burn disk fill heading to 100%; real independent incident."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "session-cache-uswest cold-cache latency, same pat-coldstart-cache, cleared in 30s; p99 980 -> 520. Warmup transient."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "billing queue_depth 12800 matches already-open INC-9120 (pat-billing-backlog). oncall-payments already engaged; do not re-page."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "frontend-uswest 5xx barely over threshold (0.06), same pat-failover-conn-reset, cleared in 25s. Reconnect churn."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "search-uswest JVM warmup GC, same pat-jvm-warmup-gc, cleared in 32s. Warmup transient."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "edge-lb 503, same pat-failover-dns-reresolve, cleared in 35s. Re-resolution churn, later oscillation."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — region-failover-mixed

A planned us-east -> us-west failover at 03:00 shifted live traffic. Most of the batch is
the expected churn of that cutover; three real page-class incidents are buried in it.

## Cutover churn (suppress)
P01-P05, P09-P12, P15, P16, P18, P20-P22 all fire in the first few minutes after 03:00,
carry the `failover-cutover-2026.05.19` deploy, have short `auto_resolved_after_s` (19-52s)
and/or high `fired_count_last_1h`, sit on neutral patterns (DNS re-resolve, conn reset,
cold-cache warmup, JVM GC, healthcheck flap, drain catch-up), and their metrics return to
baseline within ~2 minutes. Self-healing rebalance churn — do not wake anyone.

## Real incident 1 — payments-api saturation (the failover CAUSED this)
P06 (SEV1): request_queue_depth 1200 -> 9800 -> 48000 -> 71000 -> 88000, never resolves,
`pat-uswest-saturation` surging 17x negative. The target region took the shifted traffic and
did NOT recover. Root -> page. P07 (checkout 5xx) and P08 (orders p99) share the same
saturation pattern and onset window -> downstream symptoms, suppress as duplicates of P06.

## Real incident 2 — cross-region replication lag (the failover EXPOSED this)
P13 (SEV1): replication_lag_s 3 -> 180 -> 640 -> 910 -> 1180, never resolves,
`pat-xregion-replica-lag` ~10x negative. Real breach that persists. Root -> page. P14
(reporting stale reads) shares the pattern and onset -> symptom, suppress.

## Real incident 3 — audit disk fill (independent of the failover)
P17 (SEV2): disk_usage_pct rising monotonically 86 -> 93 since 02:30 (BEFORE the cutover),
no deploy, no failover correlation, never auto-resolves, only a quiet `pat-audit-disk-fill`.
Looks like noise (low severity, barely over threshold) but it is a genuine slow-burn fill
heading to 100% -> page.

## Already owned
P19 (billing backlog) duplicates open INC-9120; a human is engaged -> suppress.

Page P06, P13, P17; suppress the rest. See `tests/ground_truth.json` for per-page rationale.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
