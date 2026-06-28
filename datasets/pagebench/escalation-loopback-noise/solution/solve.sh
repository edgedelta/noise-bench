#!/bin/bash
# Oracle solution: write the known-correct triage decisions for escalation-loopback-noise.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "Real SEV1 Platform API HTTP 5xx at 0.41 vs 0.05, never auto-resolved, metric climbs to 0.47 and holds, pat-adminapi-5xx surging 1100% negative. Live production outage."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back meta event (P7X2K9A re-routed to same responder). Policy config defect, not a service outage."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back meta event (P7X2K9A re-routed to same responder). Policy config defect, not a service outage."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back meta event (P7X2K9A re-routed to same responder). Policy config defect, not a service outage."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI, self-cleared in 120s. Alerting-hygiene meta event, no live outage."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI, self-cleared in 110s. Alerting-hygiene meta event, no live outage."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI, self-cleared in 95s. Alerting-hygiene meta event, no live outage."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back meta event (P7X2K9A re-routed to same responder). Policy config defect, not a service outage."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "Notification-delivery confirmation (Slack/email succeeded), self-cleared in 60s. Transport event, not an incident."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI, self-cleared in 88s. Alerting-hygiene meta event, no live outage."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back meta event (P7X2K9A re-routed to same responder). Policy config defect, not a service outage."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper: 14 fires/hr, self-clears in 18s, pattern flat vs baseline."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Escalation-policy configuration warning (meta). Config hygiene, not a service outage."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI, self-cleared in 100s. Alerting-hygiene meta event, no live outage."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "Notification-delivery confirmation (Slack/email succeeded), self-cleared in 55s. Transport event, not an incident."
    },
    {
      "page_id": "P16",
      "decision": "page",
      "reason": "Independent real SEV2 incident: ingest-gateway HTTP 5xx at 0.22 vs 0.05, never auto-resolved, metric rises to 0.26 and holds, pat-ingest-5xx surging 640% negative. Different service/root than P01."
    },
    {
      "page_id": "P17",
      "decision": "page",
      "reason": "Independent real incident: checkout-api p99 latency SLO breach. Only SEV3 with a slow gradual rise (640->3360 ms vs 800 SLO), but never auto-resolves, no deploy to blame, pat-checkout-latency surging 380% negative. Sustained customer impact."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — escalation-loopback-noise

Three independent real incidents are buried under PagerDuty escalation-policy meta-noise:

- **P01** — Platform API SEV1 HTTP 5xx (0.41 vs 0.05), climbs to 0.47 and holds, pat-adminapi-5xx +1100% negative. Live outage.
- **P16** — ingest-gateway SEV2 HTTP 5xx (0.22 vs 0.05) on a different service/root, rises to 0.26 and holds, pat-ingest-5xx +640% negative. Distinct customer-facing ingestion outage, not a symptom of P01.
- **P17** — checkout-api p99 latency SLO breach (recall trap): only SEV3 and rises slowly (640 -> 3360 ms vs 800 SLO), but it never auto-resolves, has no deploy to blame, and pat-checkout-latency is +380% negative. Sustained customer slowness — must page despite the low severity.

These three have distinct services and patterns, so none collapses into another; each is its own page.

Everything else is meta/process noise — escalation loop-back warnings (P7X2K9A routed back to the same responder), missed-ack reminders on transient staging CI that self-clear in tens of seconds, notification-delivery confirmations, a policy-config warning, and an [ignore] log-volume flapper — fix the policy/process, do not page on-call.

See `tests/ground_truth.json` rationale for per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
