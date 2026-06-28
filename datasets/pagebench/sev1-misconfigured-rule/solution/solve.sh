#!/bin/bash
# Oracle solution: write the known-correct triage decisions for sev1-misconfigured-rule.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    { "page_id": "P01", "decision": "suppress", "reason": "SEV1 by label only. filesystem_pressure_pct 41 vs 40, metric flat at the 38-42 baseline, 18 fires/hr, auto-resolved in 27s; pat-fs-pressure-raterule delta 2, neutral. Onset tracks the mon-2026.05.20-rules deploy at 01:00. Benign blip mislabeled SEV1." },
    { "page_id": "P02", "decision": "suppress", "reason": "Same misconfigured rule. 42 vs 40 on image-resize, metric at baseline, 22 fires/hr, cleared in 24s. Noise." },
    { "page_id": "P03", "decision": "suppress", "reason": "Same misconfigured rule. 40.5 vs 40 on search, 26 fires/hr, cleared in 31s, metric back to 38.8. Noise." },
    { "page_id": "P04", "decision": "suppress", "reason": "Same misconfigured rule. 41.5 vs 40 on recommendation, 19 fires/hr, cleared in 22s. Noise." },
    { "page_id": "P05", "decision": "suppress", "reason": "Same misconfigured rule. 40.8 vs 40 on frontend, 30 fires/hr, cleared in 29s. Noise." },
    { "page_id": "P06", "decision": "suppress", "reason": "Same misconfigured rule. 41.2 vs 40 on notifications, 17 fires/hr, cleared in 35s. Noise." },
    { "page_id": "P07", "decision": "suppress", "reason": "Same misconfigured rule. 42.3 vs 40 on cart, 21 fires/hr, cleared in 26s. Noise." },
    { "page_id": "P08", "decision": "suppress", "reason": "Same misconfigured rule. 40.2 vs 40 on orders, 28 fires/hr, cleared in 20s. Noise." },
    { "page_id": "P09", "decision": "suppress", "reason": "Same misconfigured rule. 41.7 vs 40 on profile, 16 fires/hr, cleared in 33s. Noise." },
    { "page_id": "P10", "decision": "suppress", "reason": "Same misconfigured rule. 40.6 vs 40 on inventory, 24 fires/hr, cleared in 38s. Noise." },
    { "page_id": "P11", "decision": "suppress", "reason": "Same misconfigured rule. 41.9 vs 40 on media-proxy, 20 fires/hr, cleared in 23s. Noise." },
    { "page_id": "P12", "decision": "suppress", "reason": "Same misconfigured rule. 40.4 vs 40 on geo-lookup, 25 fires/hr, cleared in 30s, metric back to 38.4. Noise." },
    { "page_id": "P13", "decision": "suppress", "reason": "recommendation cpu 92 vs 90, GC pause (neutral, delta 4), auto-resolved in 36s; metric back to 45. Transient." },
    { "page_id": "P14", "decision": "suppress", "reason": "frontend 5xx 0.08 during fe-2026.05.20-a rollout, pat-rollout-503 neutral, auto-resolved in 44s; metric back to 0.004. Deploy transient." },
    { "page_id": "P15", "decision": "page", "reason": "payments db_pool_wait_ms 4200 vs 200, never resolved, climbing to 7300 at 02:30; pat-db-pool-exhausted surges ~12x, negative. Genuine SEV1, root of the payments pool-exhaustion incident." },
    { "page_id": "P16", "decision": "suppress", "reason": "log-archiver disk 85.4 vs 85, pat-disk-rotate neutral, 14 fires/hr, cleared in 19s, back to 83.1. Rotation flapper." },
    { "page_id": "P17", "decision": "suppress", "reason": "billing queue_depth 14800 matches already-open INC-9120 (pat-billing-backlog, oncall-payments). Already owned." },
    { "page_id": "P18", "decision": "page", "reason": "checkout 5xx 0.19 vs 0.05, never resolved, rising to 0.27 at 02:30; pat-checkout-5xx-regress surges from 0.006 baseline, negative, traces to checkout-2026.05.20-c. Genuine sustained SEV2 regression." },
    { "page_id": "P19", "decision": "suppress", "reason": "search p99 905 vs 800, cold-cache neutral, auto-resolved in 25s, back to 410. Transient." },
    { "page_id": "P20", "decision": "page", "reason": "session-store memory 91 vs 90, SEV3, never resolved, monotonic slow-burn rise 91->98.5 over ~1h45m; pat-mem-creep delta 240, negative, no deploy. Genuine slow-burn saturation." },
    { "page_id": "P21", "decision": "suppress", "reason": "image-resize cpu 91 vs 90, GC pause, auto-resolved in 32s; metric back to 46. Transient." },
    { "page_id": "P22", "decision": "suppress", "reason": "payments p99 5600, same pat-db-pool-exhausted root and onset window as P15. Downstream symptom; collapse into P15." },
    { "page_id": "P23", "decision": "page", "reason": "event-pipeline filesystem_pressure_pct: severity SEV1, related_pattern pat-fs-pressure-raterule, recent_deploy mon-2026.05.20-rules and fired_count 15 all match the P01-P12 rule-flapper crowd, but metrics.csv separates it: the flappers fall back to the 38-42 baseline within 1-2 min, whereas event-pipeline ratchets 48 -> 61 -> 74.5 -> 88 and never returns. Escalating disk fill masked by an early 41s flap. Page." },
    { "page_id": "P24", "decision": "suppress", "reason": "analytics-ingest memory_pct 78 vs 75, auto_resolved null, sustained — surface profile of a slow-burn — but analytics-2026.05.20-scaleup (01:43 replica resize) explains it: memory_pct steps from 55 to ~78 then plateaus flat (78.0/78.6/78.2/78.9) under the 90 line; pat-analytics-heap-resize delta 5, neutral. Bounded post-resize steady-state. Suppress." }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — sev1-misconfigured-rule

Severity does not equal realness here. Read behavior, not labels.

## The loud noise (precision trap)
A monitoring-rules deploy (`mon-2026.05.20-rules`, 01:00) introduced a misconfigured
`filesystem_pressure_pct` rule that tags 12 benign blips (P01-P12) as **SEV1** across the
fleet. Every behavioral feature says noise:
- `value` sits at/near the historical baseline (38-42 band; the metric history shows it
  before and right after each fire),
- `fired_count_last_1h` is high (16-30) — a fleet-wide flapper,
- `auto_resolved_after_s` is 20-38s — each fire self-clears,
- `pat-fs-pressure-raterule` has `delta_vs_baseline_pct` 2 and neutral sentiment.

Trusting the SEV1 label and paging all 12 destroys precision. Suppress every one — EXCEPT
read the trend before lumping a SEV1 filesystem alert in with them (see P23 below).

## The quiet/medium real incidents
- **P15 (payments pool exhaustion, SEV1)** — `db_pool_wait_ms` 4200 vs 200, never resolves,
  rising 1100 -> 4200 -> 7300; `pat-db-pool-exhausted` surges ~12x, negative. Root. **Page.**
  P22 is the same root pattern + onset window (payments p99) -> suppress as its symptom.
- **P18 (checkout 5xx regression, SEV2)** — 0.19 vs 0.05, never resolves, rising to 0.27;
  `pat-checkout-5xx-regress` surges from 0.006 baseline, negative, traces to a deploy.
  A lower severity than the noise, but sustained and real. **Page.**
- **P20 (session-store memory creep, SEV3)** — 91 vs 90 but a monotonic slow-burn (91 ->
  98.5 over ~1h45m), never resolves, `pat-mem-creep` negative, no deploy to blame. **Page.**
- **P23 (event-pipeline disk fill, SEV1)** — the dangerous one. Its alert fields are
  indistinguishable from the P01-P12 rule-flappers: same SEV1, same
  `pat-fs-pressure-raterule`, same `mon-2026.05.20-rules` deploy, flapper-range
  `fired_count` (15), and it even auto-resolved once (41s). Severity, rule-source,
  fired_count and pattern all point to noise. Only `metrics.csv` tells the truth: the true
  flappers snap back to the 38-42 baseline, but event-pipeline ratchets
  48 -> 61 -> 74.5 -> 88 and never returns. The early flap masked a real, escalating disk
  fill. Separate it from the crowd by TRAJECTORY, not by field. **Page.**

## The rest of the noise
GC-pause CPU blips (P13, P21, ~30s self-clear), a deploy-correlated 503 that self-healed
(P14, 44s, metric back to baseline), a chronic disk-rotation flapper (P16), a cold-cache
latency transient (P19), and a duplicate of already-open INC-9120 (P17). And **P24**
(analytics-ingest memory 78 vs 75): `auto_resolved` null and sustained makes it look like a
slow-burn, but `analytics-2026.05.20-scaleup` (01:43 replica resize) explains it — memory
steps from 55 to ~78 then PLATEAUS flat under the 90 line (`pat-analytics-heap-resize`
delta 5, neutral). Bounded post-resize steady-state, not P20's monotonic climb to 98.5 with
no deploy. Suppress all.

**Page P15, P18, P20, P23; suppress the rest.** See `tests/ground_truth.json` for detail.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
