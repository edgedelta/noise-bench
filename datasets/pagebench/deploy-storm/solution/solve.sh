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
    },
    {
      "page_id": "D28",
      "decision": "page",
      "reason": "Reads like a rollout transient (gwproxy-2026.04.08-a deploy at 14:31:30, auto_resolved_after_s=75, only 4 fires) but the trend disproves the heal: gateway-proxy http_5xx_rate dips to 0.006 at 14:34:30 then RE-escalates 0.072->0.13->0.21 and never returns to baseline. pat-proxy-upstream-reset (RST) is negative at 15x baseline, first_seen 14:34:30 AFTER the dip. Bad deploy that only briefly looked settled; must page."
    },
    {
      "page_id": "D29",
      "decision": "suppress",
      "reason": "Looks like a real regression (SEV2, auto_resolved_after_s null, single fire, cpu_pct rising 41->78). But imgresizer-2026.04.08-scaledown at 14:40 cut replicas 8->4, so per-pod CPU steps to a new steady plateau (76/78/77/78.5/77.5) that stays under cpu_safe_ceiling_pct=85. pat-resizer-cpu-steady is neutral, delta 3%, no error pattern. Expected post-scale-down per-pod baseline, not a regression."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — deploy-storm

Four real, page-worthy incidents hide in a storm of deploy churn. Two of them are
disguised: one real incident masquerades as a rollout transient, and one benign capacity
change masquerades as a regression.

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
- **D28** (SEV3, must-page) — REAL DISGUISED AS NOISE: every alert field says rollout
  transient (deploy gwproxy-2026.04.08-a at 14:31:30, auto_resolved_after_s=75, only 4 fires,
  value barely over threshold). The disambiguator is the metrics.csv trajectory: 5xx dips to
  0.006 at 14:34:30 (the auto-resolve) then RE-escalates 0.072 -> 0.13 -> 0.21 and never
  recovers. pat-proxy-upstream-reset (RST) is negative at 15x baseline, first_seen 14:34:30 —
  AFTER the dip, confirming the second wave. A model that trusts the single resolve event
  suppresses it (cardinal miss); the trend says page.

SUPPRESS (noise): everything else. Deploy-correlated transients that auto-resolve within
~30-55s and whose metrics return to baseline (D02-D22), a same-service cold-cache look-alike
that recovered before the real leak (D25), a chronic disk flapper (D23), a marginal agent CPU
blip (D24), and D29.
- **D29** — BENIGN DISGUISED AS REAL: it trips every page heuristic (SEV2,
  auto_resolved_after_s=null, single fire, cpu_pct climbing 41 -> 78). But the disambiguator is
  the cross-reference of deploys.json + the trend: imgresizer-2026.04.08-scaledown at 14:40 cut
  replicas 8 -> 4, so per-pod CPU legitimately steps up and then PLATEAUS (76/78/77/78.5/77.5),
  staying under the deploy's cpu_safe_ceiling_pct=85. pat-resizer-cpu-steady is neutral, delta
  3%, no error pattern. New expected steady-state from a capacity change, not a regression.

Traps:
- PRECISION trap: the wall of deploy-correlated look-alikes plus D29; paging more than one of
  them fails F1.
- RECALL traps: D27 (quiet, no deploy of its own) and D28 (auto-resolved once, looks like a
  rollout blip). Suppressing D28 is a cardinal failure; only the post-resolve re-escalation in
  metrics.csv reveals it.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
