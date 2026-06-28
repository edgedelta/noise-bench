#!/bin/bash
# Oracle solution: write the known-correct triage decisions for deploy-storm.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "D01",
      "decision": "page",
      "reason": "Real regression: deploy pg-2026.04.08-c at 14:30 leaks connections; error_rate 0.27 and climbing (0.12->0.27->0.41), auto_resolved_after_s null, pool-exhausted pattern at 21x baseline. SEV1 must page."
    },
    {
      "page_id": "D02",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on fe-2026.04.08-a rollout; auto_resolved_after_s=44, pat-rollout-503 delta 0%, frontend 5xx back to 0.004 by 14:33."
    },
    {
      "page_id": "D03",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on cart-2026.04.08-b rollout; auto_resolved_after_s=37, pat-rollout-503 delta 0%, cart 5xx back to 0.003 by 14:35."
    },
    {
      "page_id": "D04",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on search-2026.04.08-a rollout; auto_resolved_after_s=33, pat-cold-cache delta 6%, search p99 back to 260ms by 14:36."
    },
    {
      "page_id": "D05",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on orders-2026.04.08-a rollout; auto_resolved_after_s=33, pat-rollout-503 delta 0%, orders 5xx back to 0.004 by 14:37."
    },
    {
      "page_id": "D06",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on checkout-2026.04.08-a rollout; auto_resolved_after_s=54, pat-cold-cache delta 6%."
    },
    {
      "page_id": "D07",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on rec-2026.04.08-a rollout; auto_resolved_after_s=49, pat-gc-pause delta 4%, fired 44x/hr flapper."
    },
    {
      "page_id": "D08",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on fe-2026.04.08-a rollout; auto_resolved_after_s=53, pat-gc-pause delta 4%, fired 39x/hr flapper."
    },
    {
      "page_id": "D09",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on inv-2026.04.08-a rollout; auto_resolved_after_s=33, pat-cold-cache delta 6%."
    },
    {
      "page_id": "D10",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on notif-2026.04.08-a rollout; auto_resolved_after_s=36, pat-rollout-503 delta 0%."
    },
    {
      "page_id": "D11",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on auth-2026.04.08-a rollout; auto_resolved_after_s=32, pat-cold-cache delta 6%, auth p99 back to 240ms by 14:33."
    },
    {
      "page_id": "D12",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on cart-2026.04.08-b rollout; auto_resolved_after_s=35, pat-gc-pause delta 4%, fired 42x/hr flapper."
    },
    {
      "page_id": "D13",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on search-2026.04.08-a rollout; auto_resolved_after_s=41, pat-rollout-503 delta 0%, value 0.058 barely over threshold."
    },
    {
      "page_id": "D14",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on orders-2026.04.08-a rollout; auto_resolved_after_s=34, pat-gc-pause delta 4%, fired 40x/hr flapper."
    },
    {
      "page_id": "D15",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on checkout-2026.04.08-a rollout; auto_resolved_after_s=41, pat-rollout-503 delta 0%."
    },
    {
      "page_id": "D16",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on inv-2026.04.08-a rollout; auto_resolved_after_s=37, pat-gc-pause delta 4%, value 90.5 barely over 90."
    },
    {
      "page_id": "D17",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on fe-2026.04.08-a rollout; auto_resolved_after_s=46, pat-gc-pause delta 4%, value 86 barely over 85."
    },
    {
      "page_id": "D18",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on rec-2026.04.08-a rollout; auto_resolved_after_s=37, pat-cold-cache delta 6%."
    },
    {
      "page_id": "D19",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on notif-2026.04.08-a rollout; auto_resolved_after_s=46, pat-gc-pause delta 4%, fired 24x/hr flapper."
    },
    {
      "page_id": "D20",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on auth-2026.04.08-a rollout; auto_resolved_after_s=45, pat-rollout-503 delta 0%, value 0.057 barely over threshold."
    },
    {
      "page_id": "D21",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on cart-2026.04.08-b rollout; auto_resolved_after_s=51, pat-gc-pause delta 4%, value 85.5 barely over 85."
    },
    {
      "page_id": "D22",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on search-2026.04.08-a rollout; auto_resolved_after_s=34, pat-gc-pause delta 4%, fired 21x/hr flapper."
    },
    {
      "page_id": "D23",
      "decision": "suppress",
      "reason": "Chronic disk flapper, 14 fires/hr, auto_resolved_after_s=19 on rotation, pat-disk-rotate delta 0%. No deploy."
    },
    {
      "page_id": "D24",
      "decision": "suppress",
      "reason": "Marginal CPU blip on the agent, value 90.5 over 90, auto_resolved_after_s=36, pat-gc-pause delta 4%. No deploy."
    },
    {
      "page_id": "D25",
      "decision": "suppress",
      "reason": "Same service/deploy as D01 but a cold-cache latency blip (pat-cold-cache delta 6%) that auto_resolved in 49s; pg p99 back to 230ms by 14:30. Distinct from the error_rate regression; do not double-page."
    },
    {
      "page_id": "D26",
      "decision": "page",
      "reason": "Real regression: SECOND orders deploy orders-2026.04.08-b at 14:46 (distinct from the innocent -a rollout); error_rate 0.18 and climbing (0.14->0.18->0.23), auto_resolved_after_s null, pat-orders-null-deref at 18x baseline. SEV1 must page."
    },
    {
      "page_id": "D27",
      "decision": "page",
      "reason": "Slow-burn downstream break from the 14:30 auth key rotation: session-service token_validation_error_rate rising monotonically (0.04->0.07->0.11->0.15), auto_resolved_after_s null, pat-jwt-verify-fail (kid not found) at 9x baseline. No deploy on session-service itself, so it looks quiet, but it never recovers."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — deploy-storm

Three real, page-worthy incidents hide in a storm of self-healing deploy churn.

PAGE (real incidents):
- **D01** (SEV1, must-page): payment-gateway pool leak from pg-2026.04.08-c. error_rate
  climbs 0.12 -> 0.27 -> 0.41, never auto-resolves, pat-pg-pool-exhausted at 21x baseline.
- **D26** (SEV1, must-page): a SECOND orders deploy, orders-2026.04.08-b at 14:46 — separate
  from the innocent orders-2026.04.08-a rollout that fired the earlier transients (D05/D14).
  error_rate climbs 0.14 -> 0.18 -> 0.23, never auto-resolves, pat-orders-null-deref at 18x.
- **D27** (SEV2): config/secret rotation fallout. The 14:30 auth "rotate keys" deploy left
  session-service unable to verify JWTs (kid not found). token_validation_error_rate rises
  0.04 -> 0.07 -> 0.11 -> 0.15 and never auto-resolves. It has NO deploy of its own, low
  severity and a gradual rise, so it reads like noise — but it is a genuine downstream break.

SUPPRESS (noise): everything else. Deploy-correlated transients that auto-resolve within
~30-55s and whose metrics return to baseline (D02-D22), a same-service cold-cache look-alike
that recovered before the real leak (D25), a chronic disk flapper (D23), and a marginal
agent CPU blip (D24). High fired_count_last_1h + small auto_resolved_after_s + near-zero
pattern delta + recovered metric trend = churn, not an incident.

The precision trap is the wall of deploy-correlated look-alikes; paging more than one of
them fails F1. The recall trap is D27, which a conservative model suppresses because it is
quiet and has no deploy to blame.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
