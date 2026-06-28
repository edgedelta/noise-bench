#!/bin/bash
# Oracle solution: write the known-correct triage decisions for slow-burn-saturation.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "suppress",
      "reason": "edge-router 5xx tagged SEV1 but a health-check flap: 18 fires/hr, self-clears in 34s, metric snaps 0.21 -> 0.004 next minute. pat-lb-healthcheck-flap neutral, ~0% delta."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "Same edge-router health-check flapper, another oscillation (18 fires/hr, cleared in 29s, back to 0.005)."
    },
    {
      "page_id": "P03",
      "decision": "page",
      "reason": "payments-ledger memory_pct rising monotonically 62->69->77->84->91->96, single fire, never auto-resolves, no deploy. pat-ledger-heap-growth negative. Leak on a critical stateful service minutes from OOM."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "recommendation cpu tagged SEV1 but a GC-pause spike: 11 fires/hr, cleared in 26s, snaps 97 -> 46. pat-gc-pause neutral, ~4% delta."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "frontend 5xx during fe-2026.03.12-a rollout, auto-resolved in 51s, back to 0.003. Deploy transient."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "checkout cpu during the same fe-2026.03.12-a rollout, auto-resolved in 44s, back to 47. Deploy transient."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "search cold-cache latency blip, auto-resolved in 22s, back to 210."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "media-transcode queue 8200 but draining 8200->3100->900 over the next 30m, no re-fire, pat-transcode-backlog neutral. Already recovering."
    },
    {
      "page_id": "P09",
      "decision": "page",
      "reason": "postgres-primary disk_usage_pct rising monotonically 74->78->82->88->93->97, single fire, never auto-resolves, no deploy. pat-wal-disk-fill negative. DB disk minutes from 100% = imminent hard outage."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "recommendation cpu GC-pause flapper again (11 fires/hr, cleared in 31s, snaps to 49)."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "notifications 5xx, lb-healthcheck-flap family, marginally over threshold, cleared in 17s."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "image-resize cold-cache latency blip, auto-resolved in 25s, back to 180."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "search cpu GC-pause blip, auto-resolved in 33s, back to 52."
    },
    {
      "page_id": "P14",
      "decision": "page",
      "reason": "api-gateway conn_pool_utilization_pct rising monotonically 68->74->83->90->95->98, single fire, never auto-resolves, no deploy. pat-pool-saturation negative. Pool minutes from full saturation -> request stalls."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "edge-router health-check flapper again (18 fires/hr, cleared in 38s, snaps to 0.006)."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "billing queue_depth matches already-open INC-9120 (pat-billing-backlog, owned by oncall-payments since 01:28). Dedup."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "frontend cpu during the fe-2026.03.12-a rollout, auto-resolved in 36s, back to 42. Deploy transient."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "cart cold-cache latency blip, auto-resolved in 20s, back to 260."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — slow-burn-saturation

The dangerous incidents here are the QUIET ones. Three real incidents are slow-burn
saturations: a metric rising monotonically toward a hard limit, a single fire
(`fired_count_last_1h` = 1), `auto_resolved_after_s` = null, and no `recent_deploy`.
None of them screams.

1. **payments-ledger memory leak** — P03. memory_pct climbs 62 -> 69 -> 77 -> 84 -> 91 -> 96
   in metrics.csv with no recovery; pat-ledger-heap-growth is negative (gc reclaim ratio
   falling). A leak on a critical stateful service that is minutes from OOM. **Page (must).**
2. **postgres-primary disk fill** — P09. disk_usage_pct climbs 74 -> 78 -> 82 -> 88 -> 93 -> 97;
   pat-wal-disk-fill (WAL retention) negative. A DB disk minutes from 100% is an imminent
   hard outage. **Page (must).**
3. **api-gateway connection-pool saturation** — P14. conn_pool_utilization_pct climbs
   68 -> 74 -> 83 -> 90 -> 95 -> 98; pat-pool-saturation negative. The pool is minutes from
   full, after which requests stall. **Page.**

Everything else is noise that LOOKS louder:
- SEV1-tagged LB health-check flappers (P01, P02, P15) and GC-pause CPU spikes (P04, P10):
  high `fired_count_last_1h`, auto-resolve in <40s, metric snaps straight back to baseline.
- Deploy transients from fe-2026.03.12-a (P05, P06, P17): self-cleared within a minute.
- Cold-cache latency blips (P07, P12, P13, P18): sub-30s auto-resolve, metric recovers.
- media-transcode backlog (P08): queue is already draining (8200 -> 3100 -> 900).
- billing (P16): duplicate of already-open INC-9120; a human owns it.

Triaging on severity tag or loudness inverts the right answer. Page the three slow-burns
(P03, P09, P14); suppress the loud-but-benign rest.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
