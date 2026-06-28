#!/bin/bash
# Oracle solution: write the known-correct triage decisions for mixed-triage-heavy.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "api-edge 5xx 0.82 vs 0.05, pat-edge-upstream-down surging 8800% from ~zero, never auto-resolved, still 0.85 at 03:00. Independent SEV1 edge outage."
    },
    {
      "page_id": "P02",
      "decision": "page",
      "reason": "payments-db conn_pool pinned at 100% (41->78->100, still 100 at 02:45), pat-pool-exhausted +2600%, never auto-resolves. Root of the payments cascade. SEV1."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "Downstream symptom of P02: checkout 5xx via pat-pool-exhausted, ~45s after the DB page. Collapse into the one cascade."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Downstream symptom of P02: orders p99 via pat-pool-exhausted, ~80s after the DB page. Duplicate of the cascade."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "Downstream symptom of P02: fulfillment error_rate, same pat-pool-exhausted root. Part of the one cascade."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "log-archiver disk flapper: 14 fires/hr, clears in 23s (back to 83), pat-disk-rotate delta 0%."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Same disk flapper as P06, another oscillation (14/hr, cleared in 19s)."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "ingest-buffer disk-rotate flapper: 11/hr, cleared in 26s, back to 82."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "recommendation cpu 94% tagged SEV1 but 9 fires/hr, auto-resolved in 31s (back to 46), neutral pat-gc-pause. Severity label does not match the evidence."
    },
    {
      "page_id": "P10",
      "decision": "page",
      "reason": "metering-pipeline consumer_lag rising monotonically 150k->395k across the window, never auto-resolves, no deploy, pat-metering-lag +240% negative. Quiet slow-burn that never recovers."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "search cpu 92% tagged SEV1 but 7/hr, auto-resolved in 27s (back to 51), neutral pat-gc-pause."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "notifications queue marginally over threshold during batch drain, cleared in 22s (back to 3100)."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "payments-api queue matches already-open INC-9142 (pat-billing-backlog, oncall-payments). A human is already engaged."
    },
    {
      "page_id": "P14",
      "decision": "page",
      "reason": "search-indexer index_error_rate spiked to 0.34 after idx-2026.05.20-c, dipped to 0.11 then climbed back to 0.29-0.31 and stayed; never auto-resolved, pat-index-write-fail +520%. Deploy regression that did not recover."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "frontend 5xx bump during fe-2026.05.20-a rollout, auto-resolved in 44s (back to 0.004). Deploy transient."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "frontend cpu settle during the same fe rollout, auto-resolved in 36s (back to 45)."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "cart cold-cache latency blip, auto-resolved in 29s (back to 380)."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "image-resize cold-cache latency blip, recovered in 25s (back to 410)."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "auth cpu 90.5% tagged SEV1 but 12/hr, auto-resolved in 18s (back to 47), neutral pat-gc-pause."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "billing 5xx fractionally over threshold, 3/hr, cleared in 20s (back to 0.006)."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "Downstream symptom of P02: orders p99 via pat-pool-exhausted, within the cascade window. Duplicate."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "recommendation latency blip near stale rec-2026.05.19-d, auto-resolved in 34s (back to 420)."
    },
    {
      "page_id": "P23",
      "decision": "suppress",
      "reason": "session-store memory blip during cache eviction, auto-resolved in 28s (back to 84)."
    },
    {
      "page_id": "P24",
      "decision": "suppress",
      "reason": "checkout cpu blip 5/hr, auto-resolved in 24s (back to 52), neutral pat-gc-pause. Coincides with cascade onset but unrelated."
    },
    {
      "page_id": "P25",
      "decision": "suppress",
      "reason": "search-indexer cpu settle during idx-2026.05.20-c, auto-resolved in 32s (back to 49), neutral pat-rollout-503. Distinct from the P14 index_error_rate regression."
    },
    {
      "page_id": "P26",
      "decision": "suppress",
      "reason": "gateway-canary synthetic probe 503: 8/hr, auto-resolved in 17s, pat-canary-probe delta 0%. SEV1 label on a synthetic probe, not real traffic."
    },
    {
      "page_id": "P27",
      "decision": "suppress",
      "reason": "analytics-batch queue marginally over threshold during batch drain, cleared in 21s (back to 2400)."
    },
    {
      "page_id": "P28",
      "decision": "suppress",
      "reason": "Downstream symptom of P02: cart error_rate via pat-pool-exhausted, within the cascade window. Duplicate."
    },
    {
      "page_id": "P29",
      "decision": "suppress",
      "reason": "image-resize cpu blip auto-resolved in 30s (back to 48), neutral pat-gc-pause."
    },
    {
      "page_id": "P30",
      "decision": "page",
      "reason": "token-broker auth_error_rate looks like a flapper (auto_resolved in 58s, 5 fires/hr) but metrics.csv re-escalates after the single auto-resolve: 0.12 -> 0.02 -> 0.09 (02:08) -> 0.18 (02:25) -> 0.23 (03:00), never back to the 0.004 baseline; pat-token-mint-fail +610% negative. Escalating auth outage, not a flap."
    },
    {
      "page_id": "P31",
      "decision": "suppress",
      "reason": "ledger-worker memory 40 -> 71 with no auto-resolve looks like a leak, but deploy ledger-2026.05.20-b scaled replicas 12 -> 8 at 02:34; per-pod memory plateaus flat at ~72 through 03:20, ~18 pts under the 90 limit. Elevated-but-stable new normal from the capacity change."
    },
    {
      "page_id": "P32",
      "decision": "suppress",
      "reason": "Downstream symptom of P02: shipping error_rate via pat-pool-exhausted, ~01:45 inside the cascade window. Duplicate of the payments-pool incident."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — mixed-triage-heavy

Five page-class real incidents are buried in a busy 32-alert batch; everything else is noise.

1. **api-edge outage** — P01 (http_5xx_rate 0.82, pat-edge-upstream-down +8800% from
   ~zero, never resolves, still 0.85 at 03:00). Loud independent SEV1 -> page.
2. **payments-pool cascade** — P02 (payments-db conn_pool 100%, pat-pool-exhausted
   +2600%, never resolves) is the SEV1 root. P03/P04/P05/P21/P28/P32 all share
   pat-pool-exhausted and fire inside the same onset window -> collapse into the one
   incident and suppress as duplicates. Page only the root (P02).
3. **metering slow-burn** — P10 (metering-pipeline consumer_lag climbing monotonically
   150k -> 395k across the window, no deploy, never auto-resolves, pat-metering-lag
   +240% negative). Low severity and undramatic but a genuine regression -> page.
4. **search-indexer deploy regression** — P14 (index_error_rate jumped to 0.34 right
   after idx-2026.05.20-c, dipped to 0.11 then climbed back to ~0.30 and stayed; never
   auto-resolves, pat-index-write-fail +520%). The dip makes it look recovered, but the
   metric trend shows it did not -> page. (Note: P25 is a separate cpu settle on the same
   deploy that DID auto-resolve in 32s -> suppress.)
5. **token-broker auth outage that flapped first** — P30 (auth_error_rate auto_resolved
   once in 58s with 5 fires/hr, so the alert fields read like a flapper). The metrics
   trend disambiguates: it only dipped to 0.02 then re-escalated 0.09 -> 0.18 -> 0.23
   through 03:00, never back to its 0.004 baseline; pat-token-mint-fail +610% negative.
   First flap of an escalating outage -> page.

Noise to suppress:
- SEV1-mislabeled GC/canary flappers: P09, P11, P19, P26 (high fires/hr, sub-minute
  auto-resolve, neutral pattern delta; the severity tag does not match the evidence).
- Disk-rotate flappers: P06, P07, P08 (~11-14 fires/hr, clear in <30s, delta 0%).
- Recovered deploy transients: P15, P16, P22, P25.
- Batch-drain / cold-cache / cache-evict sub-minute transients: P12, P17, P18, P20,
  P23, P24, P27, P29.
- Duplicate of already-open INC-9142: P13 (payments-api queue backlog, already owned).
- Capacity-change steady state mistaken for a leak: P31 (ledger-worker memory rose
  40 -> 71 with no auto-resolve, but ledger-2026.05.20-b scaled replicas 12 -> 8 at
  02:34 and the metric plateaus flat at ~72 well under the 90 limit). New safe normal,
  not a regression -> suppress.

Page P01, P02, P10, P14, P30; suppress the other 27.

See `tests/ground_truth.json` rationale for per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
