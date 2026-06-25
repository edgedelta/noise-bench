#!/bin/bash
# Oracle solution: write the known-correct triage decisions for ai-platform-alert-noise.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "Real AI platform outage: OnCall AI Workflow Errors at 0.52 workflow_500_rate vs 0.05, never auto-resolved, pat-ai-workflow-500 surging negative right after the ai-agent-svc-2026.06.21-b deploy (predefined-agent lookup / probe regression). This is a genuine ai-agent-svc outage. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (78% vs 75%): a cost/usage warning, not an outage. Capacity/billing signal \u2014 track for budget, do not page on-call."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (82% vs 75%): a cost/usage warning, not an outage. Capacity/billing signal \u2014 track for budget, do not page on-call."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (85% vs 75%): a cost/usage warning, not an outage. Capacity/billing signal \u2014 track for budget, do not page on-call."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "Spending Cap budget alert (91% of cap on ai-memory-svc): cost-governance noise, no service degradation. Suppress (finance/budget follow-up, not a page)."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Spending Cap budget alert (93% of cap on ai-agent-svc): cost-governance noise, no service degradation. Suppress (finance/budget follow-up, not a page)."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Spending Cap budget alert (95% of cap on inference-runner): cost-governance noise, no service degradation. Suppress (finance/budget follow-up, not a page)."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (76% vs 75%): a cost/usage warning, not an outage. Capacity/billing signal \u2014 track for budget, do not page on-call."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper: 17 fires/hr, self-clears in 18s. Noise."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper: 19 fires/hr, self-clears in 21s. Noise."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "Transient CPU blip on ai-memory-svc, auto-resolved in 44s. Self-healed. Noise."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "Transient CPU blip on inference-runner, auto-resolved in 37s. Self-healed. Noise."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Spending Cap budget alert (90.5% of cap on ai-memory-svc): cost-governance noise, no service degradation. Suppress (finance/budget follow-up, not a page)."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Transient Workflow WARN spike, recovered in 39s. Noise."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (75.5% vs 75%): a cost/usage warning, not an outage. Capacity/billing signal \u2014 track for budget, do not page on-call."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor flapper: 16 fires/hr, self-clears in 20s. Noise."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "Transient CPU blip on ai-agent-svc, auto-resolved in 41s. Self-healed. Noise."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-ai-workflow-500 root): AI Assistant Overall Error Monitor firing on the same outage. Collapse into the ai-agent-svc incident."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-ai-workflow-500 root): workflow-engine 500s on the shared failure path. Collapse into the AI outage incident."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "Spending Cap budget alert (90.2% of cap on inference-runner): cost-governance noise, no service degradation. Suppress (finance/budget follow-up, not a page)."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — ai-platform-alert-noise

The single real, must-page incident is **P01**: OnCall AI Workflow Errors on ai-agent-svc (workflow_500_rate 0.52, never recovered, surging pat-ai-workflow-500) right after the ai-agent-svc-2026.06.21-b deploy — a genuine AI runtime outage. P18 (AI Assistant Overall Error Monitor) and P19 (workflow-engine 500s) are downstream symptoms on the same root and collapse into P01. All LLM token-usage Warns and Spending Cap budget alerts are cost/governance noise, not outages; the rest are [ignore] flappers, CPU blips, and transient WARN spikes.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
