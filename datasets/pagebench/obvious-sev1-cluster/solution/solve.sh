#!/bin/bash
# Oracle solution: write the known-correct triage decisions for obvious-sev1-cluster.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "A01",
      "decision": "page",
      "reason": "payments-db connection pool exhausted to 0 (threshold 10), never auto-resolved, held at 0 through 02:40; pat-pgpool-exhausted surges 1800% negative. Root of the DB outage. SEV1."
    },
    {
      "page_id": "A02",
      "decision": "suppress",
      "reason": "orders p99 11.2s, same pat-pgpool-exhausted root, fired 50s after A01. Downstream symptom; collapse into A01."
    },
    {
      "page_id": "A03",
      "decision": "suppress",
      "reason": "cart error_rate 0.28, same pat-pgpool-exhausted root, within ~80s of A01. Downstream symptom; collapse into A01."
    },
    {
      "page_id": "A04",
      "decision": "page",
      "reason": "checkout http_5xx_rate 0.61 vs 0.05, never auto-resolved, held at 0.58-0.64 through 02:40; pat-checkout-5xx surges 2600% negative. Independent SEV1 checkout outage."
    },
    {
      "page_id": "A05",
      "decision": "suppress",
      "reason": "web-bff 5xx 0.33, same pat-checkout-5xx root, fired 40s after A04. Downstream symptom; collapse into A04."
    },
    {
      "page_id": "A06",
      "decision": "page",
      "reason": "api-gateway p99 4.2s vs 1.0s, monotonically rising 4200->5600 through 02:45, never auto-resolved; pat-apigw-slow-upstream negative and growing. Independent sustained SEV2 latency breach."
    },
    {
      "page_id": "A07",
      "decision": "suppress",
      "reason": "log-archiver disk flapper: 18 fires/hr, oscillates just over 85%, auto-resolved in 24s; metric back to 82."
    },
    {
      "page_id": "A08",
      "decision": "suppress",
      "reason": "Same disk flapper as A07 (18 fires/hr, auto-resolved in 21s, back to 82)."
    },
    {
      "page_id": "A09",
      "decision": "suppress",
      "reason": "recommendation cpu blip auto-resolved in 33s; back to 46. Sub-minute transient."
    },
    {
      "page_id": "A10",
      "decision": "suppress",
      "reason": "search cpu blip auto-resolved in 28s; back to 49. Sub-minute transient."
    },
    {
      "page_id": "A11",
      "decision": "suppress",
      "reason": "frontend 5xx bump during fe-2026.03.12-a rollout, auto-resolved in 40s; back to 0.003. Deploy transient that recovered."
    },
    {
      "page_id": "A12",
      "decision": "suppress",
      "reason": "frontend cpu settle during the same fe-2026.03.12-a rollout, auto-resolved in 36s; back to 41. Deploy transient that recovered."
    },
    {
      "page_id": "A13",
      "decision": "suppress",
      "reason": "image-resize cold-cache latency blip, auto-resolved in 22s; back to 540. Transient."
    },
    {
      "page_id": "A14",
      "decision": "suppress",
      "reason": "notifications queue marginally over threshold during batch drain, auto-resolved in 19s; back to 2300. Routine."
    },
    {
      "page_id": "A15",
      "decision": "suppress",
      "reason": "image-resize cpu flapper: 12 fires/hr, auto-resolved in 30s; back to 43."
    },
    {
      "page_id": "A16",
      "decision": "suppress",
      "reason": "notifications 5xx flicker barely over threshold, auto-resolved in 20s; back to 0.002. Transient."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — obvious-sev1-cluster

Three page-class incidents are buried in the batch; everything else is noise.

1. **payments-db outage** — A01 (connection_pool_available pinned at 0 vs threshold 10,
   pat-pgpool-exhausted surging 1800%, never resolves) is the root SEV1. A02 (orders p99)
   and A03 (cart errors) share the same root pattern and fire within ~80s downstream ->
   suppress as duplicates of the one incident.
2. **checkout 5xx outage** — A04 (checkout http_5xx_rate 0.61, pat-checkout-5xx surging
   2600%, held 0.58-0.64, never resolves) is an independent SEV1. A05 (web-bff 5xx, same
   pattern, ~40s later) is the downstream symptom -> suppress.
3. **api-gateway latency breach** — A06 (p99 rising 4200->5600, never resolves,
   pat-apigw-slow-upstream negative) is a sustained SEV2. Page it (non-must).

All remaining alerts are noise: disk flappers (A07/A08, 18 fires/hr, clear in <25s),
sub-minute auto-resolved cpu/latency/queue transients (A09/A10/A13/A14/A15/A16), and
deploy-correlated blips that recovered to baseline (A11/A12 during fe-2026.03.12-a).

Page the three real incidents (A01, A04, A06); suppress the rest.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
