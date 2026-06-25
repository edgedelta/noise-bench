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
      "reason": "Real regression: deploy pg-2026.04.08-c at 14:30 leaks connections; error rate 27% and climbing, NEVER auto-resolved, pool-exhausted pattern at 22x baseline. This is the one bad deploy in the storm. SEV1 must page."
    },
    {
      "page_id": "D02",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on fe-2026.04.08-a rollout; self-healed in 44s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D03",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on cart-2026.04.08-b rollout; self-healed in 37s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D04",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on search-2026.04.08-a rollout; self-healed in 33s (pat-cold-cache). Expected churn during the deploy window."
    },
    {
      "page_id": "D05",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on orders-2026.04.08-a rollout; self-healed in 33s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D06",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on checkout-2026.04.08-a rollout; self-healed in 54s (pat-cold-cache). Expected churn during the deploy window."
    },
    {
      "page_id": "D07",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on rec-2026.04.08-a rollout; self-healed in 49s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D08",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on fe-2026.04.08-a rollout; self-healed in 53s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D09",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on inv-2026.04.08-a rollout; self-healed in 33s (pat-cold-cache). Expected churn during the deploy window."
    },
    {
      "page_id": "D10",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on notif-2026.04.08-a rollout; self-healed in 36s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D11",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on auth-2026.04.08-a rollout; self-healed in 32s (pat-cold-cache). Expected churn during the deploy window."
    },
    {
      "page_id": "D12",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on cart-2026.04.08-b rollout; self-healed in 35s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D13",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on search-2026.04.08-a rollout; self-healed in 41s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D14",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on orders-2026.04.08-a rollout; self-healed in 34s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D15",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on checkout-2026.04.08-a rollout; self-healed in 41s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D16",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on inv-2026.04.08-a rollout; self-healed in 37s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D17",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on fe-2026.04.08-a rollout; self-healed in 46s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D18",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on rec-2026.04.08-a rollout; self-healed in 37s (pat-cold-cache). Expected churn during the deploy window."
    },
    {
      "page_id": "D19",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on notif-2026.04.08-a rollout; self-healed in 46s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D20",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on auth-2026.04.08-a rollout; self-healed in 45s (pat-rollout-503). Expected churn during the deploy window."
    },
    {
      "page_id": "D21",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on cart-2026.04.08-b rollout; self-healed in 51s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D22",
      "decision": "suppress",
      "reason": "Deploy-correlated transient on search-2026.04.08-a rollout; self-healed in 34s (pat-gc-pause). Expected churn during the deploy window."
    },
    {
      "page_id": "D23",
      "decision": "suppress",
      "reason": "Chronic disk flapper, 14 fires/hr, clears on rotation in 19s. Not deploy related, still pure noise."
    },
    {
      "page_id": "D24",
      "decision": "suppress",
      "reason": "Marginal CPU blip on the agent, auto-resolved in 36s. Noise."
    },
    {
      "page_id": "D25",
      "decision": "suppress",
      "reason": "Same service/deploy as D01 but a cold-cache latency blip that self-healed in 49s BEFORE the pool leak manifested. Distinct from the real error-rate regression; do not double-page."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — deploy-storm

This is the reference triage. The single real, must-page incident is **D01**.
Every other page is noise: chronic flappers, sub-minute transients that auto-resolved,
downstream symptoms that collapse into the one root incident, a duplicate of an
already-open incident, or deploy-correlated churn that self-healed.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
