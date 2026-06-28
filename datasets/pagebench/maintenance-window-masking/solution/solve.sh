#!/bin/bash
# Oracle solution: write the known-correct triage decisions for maintenance-window-masking.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "M01",
      "decision": "suppress",
      "reason": "checkout 5xx during the node-pool drain (pat-conn-drain, in maintenance scope). 0.14 -> 0.006 by 01:12, auto_resolved 95s. Expected, time-boxed maintenance blast."
    },
    {
      "page_id": "M02",
      "decision": "suppress",
      "reason": "inventory read-only-transaction errors (pat-migrate-readonly, in scope) from the schema migration. 0.21 -> 0.02, auto_resolved 120s. Expected migration churn under CHG-5521."
    },
    {
      "page_id": "M03",
      "decision": "page",
      "reason": "cdn-edge origin_error_rate 0.61 -> 0.72, NOT in maintenance scope, no deploy, pat-origin-5xx surging 9999x, never auto-resolves. Genuine origin outage unrelated to the window. SEV1."
    },
    {
      "page_id": "M04",
      "decision": "suppress",
      "reason": "orders-db connection_errors during migration (pat-migrate-readonly, in scope). 0.33 -> 0.03, auto_resolved 110s. Expected drain."
    },
    {
      "page_id": "M05",
      "decision": "suppress",
      "reason": "payments-worker queue_depth from node drain (pat-conn-drain, in scope). 8200 -> 1400, auto_resolved 140s. Expected, recovered."
    },
    {
      "page_id": "M06",
      "decision": "suppress",
      "reason": "checkout p99 latency during drain (pat-conn-drain, in scope). 1450 -> 280, auto_resolved 88s. Expected, recovered."
    },
    {
      "page_id": "M07",
      "decision": "suppress",
      "reason": "inventory p99 latency during migration (pat-migrate-readonly, in scope). 2100 -> 320, auto_resolved 105s. Expected, recovered."
    },
    {
      "page_id": "M08",
      "decision": "suppress",
      "reason": "log-archiver disk oscillation, 14 fires/hr, clears in 21s on rotation; matches already-tracked INC-9120."
    },
    {
      "page_id": "M09",
      "decision": "page",
      "reason": "orders-db replication_lag is in scope BUT exceeds the expected blast: lag climbs 140 -> 380 -> 690 -> 910s and never recovers, pattern is pat-repl-stall (2400x, negative), NOT the benign pat-migrate-readonly the other in-scope alerts recover from. Real regression riding the migration. SEV1."
    },
    {
      "page_id": "M10",
      "decision": "suppress",
      "reason": "checkout 5xx sharing pat-repl-stall with M09, fired ~90s later, climbing and never resolving. Downstream symptom of the M09 replication-stall incident; collapse into M09."
    },
    {
      "page_id": "M11",
      "decision": "suppress",
      "reason": "payments-worker error_rate sharing pat-repl-stall with M09, fired ~2 min later, climbing. Downstream symptom of the M09 incident; collapse into M09."
    },
    {
      "page_id": "M12",
      "decision": "suppress",
      "reason": "recommendation cpu blip from the pre-window rec-2026.04.07-e deploy (pat-gc-pause). 92 -> 48 next minute, auto_resolved 36s. Outside the window, self-healed."
    },
    {
      "page_id": "M13",
      "decision": "suppress",
      "reason": "inventory read-only errors (pat-migrate-readonly, in scope), 0.18 -> 0.003, auto_resolved 115s. Another expected migration oscillation."
    },
    {
      "page_id": "M14",
      "decision": "suppress",
      "reason": "checkout 5xx during drain (pat-conn-drain, in scope), 0.12 then recovered, auto_resolved 92s. Expected maintenance blast."
    },
    {
      "page_id": "M15",
      "decision": "page",
      "reason": "search-indexer memory 91 and rising 79 -> 91 -> 95 -> 98, NOT in maintenance scope, no deploy, pat-heap-growth negative, never auto-resolves. Quiet slow-burn leak independent of the window. SEV2."
    },
    {
      "page_id": "M16",
      "decision": "suppress",
      "reason": "payments-worker queue_depth from drain (pat-conn-drain, in scope), 7600 -> 1300, auto_resolved 130s. Expected, recovered."
    },
    {
      "page_id": "M17",
      "decision": "suppress",
      "reason": "log-archiver disk oscillation again, clears in 19s; INC-9120."
    },
    {
      "page_id": "M18",
      "decision": "suppress",
      "reason": "orders-db connection_errors (pat-migrate-readonly, in scope) at 02:02, 0.29 -> 0.02, auto_resolved 118s. Late-window migration drain, recovered."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — maintenance-window-masking

An announced maintenance window (CHG-5521: schema migration + blue node-pool upgrade,
01:00–03:00Z, scope = orders-db/checkout/inventory/payments-worker) produces a wave of
EXPECTED benign alerts on the scoped services. Each of those carries: a maintenance
`recent_deploy` (maint-2026.04.08-dbmigrate / -nodeupgrade), a benign maintenance pattern
(pat-migrate-readonly or pat-conn-drain, neutral sentiment), a short `auto_resolved_after_s`,
and a metric trend that spikes then **recovers to baseline**. Those are M01, M02, M04, M05,
M06, M07, M13, M14, M16, M18 — suppress. M08/M17 are a known disk flapper (INC-9120) and
M12 is a pre-window deploy blip that self-healed.

Three real page-class incidents hide in the maintenance noise:

1. **M03 — cdn-edge origin outage (must-page, SEV1).** cdn-edge is NOT in the maintenance
   scope, has no deploy, and pat-origin-5xx is surging 9999x with negative sentiment and
   never auto-resolves (origin_error_rate 0.61 -> 0.72). The window cannot explain it.
2. **M09 — orders-db replication stall (must-page, SEV1).** orders-db IS in scope, so a lazy
   "it's the migration" call would suppress it. But it EXCEEDS the expected blast: the
   pattern is pat-repl-stall (2400x, negative), not the benign pat-migrate-readonly the
   other orders-db alerts (M04/M18) recover from, and replication_lag climbs 140 -> 380 ->
   690 -> 910s and never recovers. M10 (checkout 5xx) and M11 (payments-worker error_rate)
   share pat-repl-stall and fire minutes later, climbing — downstream symptoms collapsed
   into M09 and suppressed as duplicates.
3. **M15 — search-indexer heap leak (page, non-must, SEV2).** Out of scope, no deploy,
   pat-heap-growth negative, memory rising 79 -> 91 -> 95 -> 98 with no auto-resolve. A
   quiet independent slow-burn.

Page M03, M09, M15; suppress the other 15. must_page = [M03, M09]; the quiet M15 is
recall-covered (miss_budget 1) but dropping it costs F1.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
