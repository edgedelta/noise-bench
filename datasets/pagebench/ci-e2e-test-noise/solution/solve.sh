#!/bin/bash
# Oracle solution: write the known-correct triage decisions for ci-e2e-test-noise.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "Real prod web-app regression: SEV1 checkout 5xx 0.38 vs 0.02, never auto-resolved, rising (0.38 -> 0.44), corroborated by surging negative pat-web-prod-regression right after the web-2026.06.24-rel deploy. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API Staging; self-resolved in 300s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API Staging; self-resolved in 280s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on web-app; self-resolved in 260s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 240s on retry. Test instability."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 210s on retry. Test instability."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 255s on retry. Test instability."
    },
    {
      "page_id": "P08",
      "decision": "page",
      "reason": "Real prod Platform API regression: SEV1 api_5xx_ratio 0.21 vs 0.01, never auto-resolved, rising (0.21 -> 0.27), corroborated by surging negative pat-api-prod-5xx right after the platform-api-2026.06.24-rel deploy. Distinct root from P01. Cardinal must-page."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API Staging; self-resolved in 290s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on web-app; self-resolved in 270s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 200s on retry. Test instability."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper on web-app: 16 fires/hr, self-clears in 19s, flat pat-log-threshold."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper on Platform API: 18 fires/hr, self-clears in 20s, flat pat-log-threshold."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API Staging; self-resolved in 265s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 245s on retry. Test instability."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API; self-resolved in 275s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P17",
      "decision": "page",
      "reason": "Real prod data-pipeline stall: only SEV3 with no deploy, but ingest_lag_seconds climbs monotonically and never recovers (18 -> 95 -> 160 -> 240 -> 330), auto_resolved null, corroborated by negative pat-ingest-backlog. Sustained customer-facing backlog; page it despite the quiet severity."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on web-app; self-resolved in 285s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 205s on retry. Test instability."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API Staging; self-resolved in 295s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper on web-app: 15 fires/hr, self-clears in 17s, flat pat-log-threshold."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "CircleCI hourly_playwright failure on Platform API; self-resolved in 250s, neutral pat-ci-staging. Test-env signal."
    },
    {
      "page_id": "P23",
      "decision": "suppress",
      "reason": "e2e Playwright failure with flat pat-e2e-flaky, self-resolved in 220s on retry. Test instability."
    },
    {
      "page_id": "P24",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-web-prod-regression root and onset window): synthetic checkout monitor on the same regression. Collapse into the web-app incident."
    },
    {
      "page_id": "P25",
      "decision": "suppress",
      "reason": "e2e Playwright failure on Platform API with flat pat-e2e-flaky, self-resolved in 230s on retry. Test instability."
    },
    {
      "page_id": "P26",
      "decision": "suppress",
      "reason": "Tagged SEV1 by a synthetic smoke-test monitor on Platform API Staging, but it flaps (7 fires/hr), auto-resolves in 90s, shares neutral pat-ci-staging, and aligns with the innocent admin-staging-2026.06.24-d fixture deploy. Loud-looking staging test noise, not prod."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — ci-e2e-test-noise

Three independent real production incidents must surface from a flood of CI/e2e
test-environment noise:

- **P01 (page, cardinal)** — web-app checkout SEV1 5xx. value 0.38 vs 0.02, never
  auto-resolved, rising in metrics.csv (0.38 -> 0.44), backed by the surging negative
  pat-web-prod-regression and aligned with the web-2026.06.24-rel deploy.
- **P08 (page, cardinal)** — Platform API SEV1 5xx, a distinct root. api_5xx_ratio 0.21
  vs 0.01, never auto-resolved, rising (0.21 -> 0.27), backed by pat-api-prod-5xx and the
  platform-api-2026.06.24-rel deploy.
- **P17 (page)** — data-pipeline ingest stall. The quiet one: only SEV3, no deploy to
  blame, but ingest_lag_seconds rises monotonically and never recovers
  (18 -> 95 -> 160 -> 240 -> 330) with auto_resolved null and negative pat-ingest-backlog.
  Sustained, customer-facing; a conservative triager wrongly suppresses it.

Suppressed correlated/duplicate and decoy alerts:

- **P24** — synthetic-checkout symptom of P01 (same pat-web-prod-regression). Collapse into P01.
- **P26** — loud SEV1 staging smoke test that flaps (7 fires/hr), auto-resolves in 90s,
  neutral pat-ci-staging, innocent staging fixture deploy. Precision trap, suppress.

Everything else is CircleCI/staging CI failures, flaky Playwright that retried green, and
[ignore] log-threshold flappers — all flat/neutral patterns that self-resolve and must NOT
page prod on-call. See tests/ground_truth.json for the per-page rationale.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
