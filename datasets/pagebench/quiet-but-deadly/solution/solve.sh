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
      "reason": "Slow-burn real incident: error rate has climbed monotonically 2% -> 11% over 40 min (see metrics.csv), NEVER auto-resolved, no deploy to blame, upstream-timeout pattern steadily rising. Quiet but real. Must page."
    },
    {
      "page_id": "Q02",
      "decision": "suppress",
      "reason": "Disk flapper, 13 fires/hr, clears on rotation in 20s. Noise."
    },
    {
      "page_id": "Q03",
      "decision": "suppress",
      "reason": "Transient CPU blip, auto-resolved in 40s. Noise."
    },
    {
      "page_id": "Q04",
      "decision": "suppress",
      "reason": "Cold-cache latency blip, recovered in 28s. Noise."
    },
    {
      "page_id": "Q05",
      "decision": "suppress",
      "reason": "Post-deploy 5xx flicker on fe-2026.05.20-a, self-healed in 44s. The only recent deploy \u2014 tempting to blame, but it recovered and is a different service from the real incident. Suppress."
    },
    {
      "page_id": "Q06",
      "decision": "suppress",
      "reason": "Transient CPU blip, auto-resolved in 33s. Noise."
    },
    {
      "page_id": "Q07",
      "decision": "suppress",
      "reason": "Marginal queue blip during batch drain, cleared in 17s. Noise."
    },
    {
      "page_id": "Q08",
      "decision": "suppress",
      "reason": "Cold-cache latency blip, recovered in 25s. Noise."
    },
    {
      "page_id": "Q09",
      "decision": "suppress",
      "reason": "Single marginal CPU blip, auto-resolved in 48s. Noise."
    },
    {
      "page_id": "Q10",
      "decision": "suppress",
      "reason": "Same disk flapper as Q02, another oscillation. Noise."
    },
    {
      "page_id": "Q11",
      "decision": "suppress",
      "reason": "Transient CPU blip, auto-resolved in 35s. Noise."
    },
    {
      "page_id": "Q12",
      "decision": "suppress",
      "reason": "Brief memory blip, recovered in 50s. Noise."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — quiet-but-deadly

This is the reference triage. The single real, must-page incident is **Q01**.
Every other page is noise: chronic flappers, sub-minute transients that auto-resolved,
downstream symptoms that collapse into the one root incident, a duplicate of an
already-open incident, or deploy-correlated churn that self-healed.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
