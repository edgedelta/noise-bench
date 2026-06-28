#!/bin/bash
# Oracle solution: write the known-correct triage decisions for quiet-but-deadly.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "Q01",
      "decision": "page",
      "reason": "Quiet slow-burn: api-gateway error_rate climbs 0.02 -> 0.14 monotonically (metrics.csv), never auto-resolves, no deploy, pat-upstream-timeout +520%. Real. Must page."
    },
    {
      "page_id": "Q02",
      "decision": "suppress",
      "reason": "Disk flapper: fired 13x/hr, auto-resolved in 20s, barely over threshold, returns to 83 next sample. Noise."
    },
    {
      "page_id": "Q03",
      "decision": "suppress",
      "reason": "CPU blip 91 vs 90, auto-resolved in 40s, back to 43 next sample. Noise."
    },
    {
      "page_id": "Q04",
      "decision": "suppress",
      "reason": "Cold-cache latency blip 850 vs 800, recovered in 28s. Noise."
    },
    {
      "page_id": "Q05",
      "decision": "suppress",
      "reason": "Frontend 5xx 0.06 vs 0.05, deploy-correlated but dropped to 0.003 two minutes later, auto-resolved in 44s. Recovered deploy churn."
    },
    {
      "page_id": "Q06",
      "decision": "suppress",
      "reason": "CPU blip 92 vs 90, auto-resolved in 33s. Noise."
    },
    {
      "page_id": "Q07",
      "decision": "suppress",
      "reason": "Queue depth 5050 vs 5000 during batch drain, cleared in 17s. Noise."
    },
    {
      "page_id": "Q08",
      "decision": "suppress",
      "reason": "Cold-cache latency blip 820 vs 800, recovered in 25s. Noise."
    },
    {
      "page_id": "Q09",
      "decision": "suppress",
      "reason": "Marginal CPU blip 90.5 vs 90, auto-resolved in 48s. Noise."
    },
    {
      "page_id": "Q10",
      "decision": "suppress",
      "reason": "Same disk flapper as Q02, another oscillation, auto-resolved in 19s. Noise."
    },
    {
      "page_id": "Q11",
      "decision": "suppress",
      "reason": "CPU blip 91 vs 90, auto-resolved in 35s. Noise."
    },
    {
      "page_id": "Q12",
      "decision": "suppress",
      "reason": "Memory blip 86 vs 85, recovered in 50s. Noise."
    },
    {
      "page_id": "Q13",
      "decision": "page",
      "reason": "SEV1 root: payments 5xx 0.62 vs 0.02 and rising to 0.78 (metrics.csv), never auto-resolves, pat-payments-db-pool +740%. Must page."
    },
    {
      "page_id": "Q14",
      "decision": "suppress",
      "reason": "Same payments incident as Q13: same service, same root pattern pat-payments-db-pool, fired one minute later. Symptom of the db-pool exhaustion. Page the root (Q13), suppress this duplicate."
    },
    {
      "page_id": "Q15",
      "decision": "page",
      "reason": "Sustained regression: checkout p99 climbs 910 -> 1990 (metrics.csv), never auto-resolves, no deploy, pat-checkout-pool-exhaust +380%. Independent real incident. Page."
    },
    {
      "page_id": "Q16",
      "decision": "suppress",
      "reason": "Inventory 5xx is real but already owned: incidents_open.json INC-4471 covers inventory/pat-inventory-5xx, status investigating. Duplicate of an open incident."
    },
    {
      "page_id": "Q17",
      "decision": "suppress",
      "reason": "Promotions tagged SEV1 but fired 9x/hr, auto-resolved in 31s, 0.21 dropped to 0.04 next minute, deploy-correlated, pat-promo-rollout +4%. Flapping deploy churn that self-healed."
    },
    {
      "page_id": "Q18",
      "decision": "suppress",
      "reason": "Gateway-canary tagged SEV1 but fired 11x/hr, auto-resolved in 22s, 0.30 dropped to 0.02 next sample, pat-canary-misroute +2%. High-value-looking flapper that auto-resolved."
    },
    {
      "page_id": "Q19",
      "decision": "page",
      "reason": "ingest-worker open_fds. Auto-resolved once in 55s and fired only once, so the alert reads transient. But metrics.csv shows fds drop to 22000 then climb back 37000 -> 46000 -> 54000 -> 59000 -> 62500 toward the 65536 ceiling; pat-fd-accept +260% socket leak, no deploy. First flap of an escalating fd-exhaustion outage. Must page."
    },
    {
      "page_id": "Q20",
      "decision": "suppress",
      "reason": "feed-cache memory_pct rising with auto_resolved null + single fire, but deploy feed-cache-2026.05.20-c at 09:30 raised cache.max_heap_pct 55 -> 78 (oom_limit 90); memory rises to 76-77 and plateaus flat under the 78 target. Expected post-deploy steady state, pat-cache-warm +1%. Suppress."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — quiet-but-deadly

Four independent real incidents must page:

- **Q01 (api-gateway error_rate)** — quiet slow-burn. Climbs 0.02 -> 0.14
  monotonically, never auto-resolves, no deploy to blame. Easy to dismiss as
  low-grade; it is the recall trap. Must page.
- **Q13 (payments http_5xx_rate)** — loud SEV1 root. 0.62 vs 0.02 threshold and
  still rising, never auto-resolves, pattern +740%. Q14 (payments p99) is the
  same db-pool exhaustion (same service + pat-payments-db-pool) and collapses
  into Q13 as a symptom — suppress the duplicate, page the root.
- **Q15 (checkout p99_latency_ms)** — moderate sustained regression. Climbs
  910 -> 1990, never auto-resolves, distinct service/root. Page.
- **Q19 (ingest-worker open_fds)** — auto-resolved once in 55s on a single
  fire, which reads transient. The disambiguator is the post-resolve trend:
  fds drop to 22000 then climb back 37000 -> 46000 -> 54000 -> 59000 -> 62500
  toward the 65536 ceiling (pat-fd-accept +260% socket leak). The auto-resolve
  was the first flap of an fd-exhaustion outage, not a recovery. Must page.

Everything else suppresses:

- **Flappers / transients** (Q02–Q12): high fired_count and/or sub-minute
  auto-resolve, metric back to baseline, flat pattern deltas.
- **Already owned** (Q16): inventory 5xx is real but INC-4471 in
  incidents_open.json already covers it — dedup, don't double-page.
- **Precision traps** (Q17, Q18): tagged SEV1 but they flap and auto-resolve
  within ~30s and the metric snaps back; one is deploy-correlated and recovered.
  Severity-looks-real noise — paging these tanks precision.
- **Capacity-change steady state** (Q20): feed-cache memory rises with
  auto_resolved null + single fire — the same shape as Q01/Q15 — but deploy
  feed-cache-2026.05.20-c raised cache.max_heap_pct 55 -> 78 and the metric
  plateaus flat at 76-77 under that target (and well under the 90 OOM line).
  New safe normal, not a regression. Suppress.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
