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
      "reason": "Real SEV1: Platform API HTTP 5xx Error at 0.41 vs 0.05 threshold, never auto-resolved, pat-adminapi-5xx surging negative. This is a genuine missed-acknowledgement on a LIVE production outage (not a policy meta-event). Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back META event: P7X2K9A re-routed to the same responder. This is a config defect already tracked in Jira OPS-2031, not a service outage. Suppress (fix the policy, do not page on-call)."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back META event: P7X2K9A re-routed to the same responder. This is a config defect already tracked in Jira OPS-2031, not a service outage. Suppress (fix the policy, do not page on-call)."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back META event: P7X2K9A re-routed to the same responder. This is a config defect already tracked in Jira OPS-2031, not a service outage. Suppress (fix the policy, do not page on-call)."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI (hourly_playwright_sev0_staging) that self-resolved in 120s. Process/alerting-hygiene noise, no live outage."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI (hourly_playwright_sev0_staging) that self-resolved in 110s. Process/alerting-hygiene noise, no live outage."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI (hourly_playwright_sev0_staging) that self-resolved in 95s. Process/alerting-hygiene noise, no live outage."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back META event: P7X2K9A re-routed to the same responder. This is a config defect already tracked in Jira OPS-2031, not a service outage. Suppress (fix the policy, do not page on-call)."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "Notification-delivery event (Slack/email succeeded). Transport confirmation, not an incident. Noise."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI (hourly_playwright_sev0_staging) that self-resolved in 88s. Process/alerting-hygiene noise, no live outage."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "Escalation-policy loop-back META event: P7X2K9A re-routed to the same responder. This is a config defect already tracked in Jira OPS-2031, not a service outage. Suppress (fix the policy, do not page on-call)."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper: 14 fires/hr, self-clears in 18s. Noise by design."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Escalation-policy configuration warning (meta). Config hygiene, not a service outage. Suppress."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Missed-ack reminder on transient staging CI (hourly_playwright_sev0_staging) that self-resolved in 100s. Process/alerting-hygiene noise, no live outage."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "Notification-delivery event (Slack/email succeeded). Transport confirmation, not an incident. Noise."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-adminapi-5xx root, onset +2min): http-receiver error bump on the shared failure path. Collapse into the Platform API incident."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — escalation-loopback-noise

The single real, must-page incident is **P01**: a live SEV1 Platform API HTTP 5xx outage (0.41 vs 0.05, never recovered) — a genuine missed-ack on a real outage, distinct from the policy meta-noise. P16 is the downstream http-receiver symptom on the same root pattern and collapses into P01. All escalation loop-back warnings (P7X2K9A → same responder, OPS-2031), missed-ack reminders on transient staging CI, notification-delivery confirmations, and policy-config warnings are config/process META noise — fix the policy, do not page on-call.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
