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
      "reason": "Real ai-agent-svc outage: workflow_500_rate 0.52 vs 0.05, never auto-resolves, climbing in metrics.csv, pat-ai-workflow-500 surging negative (+1050%) right after the ai-agent-svc-2026.06.21-b deploy. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (78% vs 75%): pat-llm-tokens 0% delta, neutral. Cost/usage signal, not a degradation."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (82% vs 75%): pat-llm-tokens 0% delta, neutral. Cost signal, not an outage."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (85% vs 75%): pat-llm-tokens 0% delta, neutral. Cost signal, not an outage."
    },
    {
      "page_id": "P05",
      "decision": "page",
      "reason": "ai-memory-svc Memory Write Failure Rate 0.11 vs 0.02 and rising (metrics.csv 0.004->0.23), pat-ai-memory-write-fail surging negative (+380%), never auto-resolves. Quiet SEV3 but writes are failing for customers and getting worse. Must-page."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Spending Cap Hit Monitor (93% on ai-agent-svc): pat-spend-cap 0% delta, neutral. Budget governance, no degradation."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "Spending Cap Hit Monitor (95% on inference-runner): pat-spend-cap 0% delta, neutral. Budget governance, no degradation."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (76% vs 75%): pat-llm-tokens 0% delta, neutral. Cost signal."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor: 17 fires/hr, self-clears in 18s, 0% delta. Flapper."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor: 19 fires/hr, self-clears in 21s, 0% delta. Flapper."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "Default Synthetic CPU on ai-memory-svc 91% vs 90%, auto-resolved in 44s, pat-ai-cpu-blip 5% delta. Self-cleared blip."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "Default Synthetic CPU on inference-runner 92% vs 90%, auto-resolved in 37s, 5% delta. Self-cleared blip."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Spending Cap Hit Monitor (90.5% on ai-memory-svc): pat-spend-cap 0% delta, neutral. Budget governance."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Default Synthetic warn_log_rate spike 140 vs 100, auto-resolved in 39s, pat-ai-warn-transient 6% delta. Transient."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "LLM 24 Hour Token Usage Warn (75.5% vs 75%): pat-llm-tokens 0% delta, neutral. Cost signal."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "[ignore] Default Log Threshold Monitor: 16 fires/hr, self-clears in 20s, 0% delta. Flapper."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "Spending Cap Hit Monitor tagged SEV1 (90.8% on inference-runner): the SEV1 tag is a misconfigured-rule artifact over a spend_pct budget alert (pat-spend-cap 0% delta), fired 6x/hr and auto-resolved in 33s. Loud label, cost noise underneath."
    },
    {
      "page_id": "P18",
      "decision": "page",
      "reason": "Real inference-runner crashloop: inference_500_rate 0.41 vs 0.05, never auto-resolves, climbing in metrics.csv, pat-inference-crashloop surging negative (+870%, CUDA context lost / restart loop) right after the inference-runner-2026.06.21-c deploy. Independent customer-visible incident. Must-page."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "Default Synthetic gpu_mem_pct tagged SEV1 (96% vs 95%): fired 9x/hr, auto-resolved in 28s, pat-ai-gpu-blip 4% delta neutral, gpu_mem drops back to 71 in metrics.csv. High-severity label on a self-cleared warmup blip."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "Spending Cap Hit Monitor (90.2% on inference-runner): pat-spend-cap 0% delta, neutral. Budget governance."
    },
    {
      "page_id": "P21",
      "decision": "page",
      "reason": "ai-agent-svc tool_call_error_rate 0.18 vs 0.05. auto_resolved_after_s=62 and a single fire make it read as transient, but metrics.csv shows it dip to 0.02 at the auto-resolve then climb back higher and stay there (0.27->0.41->0.55), pat-ai-toolcall-err surging negative (+540%). First flap of an escalating tool-dispatch outage, distinct root from P01. Must-page."
    },
    {
      "page_id": "P22",
      "decision": "suppress",
      "reason": "inference-runner gpu_warmup_mem_pct 88 vs 85, auto_resolved_after_s=null and rising, but metrics.csv shows it plateau at 89 (well under the 95 saturation line that the gpu_mem_pct monitor uses) after the inference-runner-2026.06.21-d scale-up + model-preload deploy at 18:58 raised the resident GPU memory floor. pat-ai-gpu-warmup +3% neutral. Steady state within limits."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — ai-platform-alert-noise

Four independent real incidents must page:

- **P01** — ai-agent-svc outage. `workflow_500_rate` 0.52 vs 0.05, never auto-resolves,
  climbing in metrics.csv (0.003 -> 0.52 -> 0.58), `pat-ai-workflow-500` surging negative
  (+1050%) right after the `ai-agent-svc-2026.06.21-b` deploy. SEV1 cardinal page.
- **P18** — inference-runner crashloop. `inference_500_rate` 0.41 vs 0.05, never
  auto-resolves, climbing (0.004 -> 0.49), `pat-inference-crashloop` surging negative
  (+870%, CUDA context lost / restart loop) right after the `inference-runner-2026.06.21-c`
  deploy. Independent SEV2 customer-visible incident.
- **P05** — ai-memory-svc write-failure spike. `memory_write_error_rate` 0.11 vs 0.02 and
  rising in a slow sustained climb (0.004 -> 0.021 -> 0.11 -> 0.17 -> 0.23),
  `pat-ai-memory-write-fail` surging negative (+380%), never auto-resolves, no deploy to
  blame. Tagged only SEV3 and fired once, so it reads as quiet — but customer writes are
  failing and worsening. This is the recall trap.
- **P21** — ai-agent-svc tool-call errors. `tool_call_error_rate` 0.18 vs 0.05. The alert
  auto-resolved once in 62s and fired only once, so it reads as a transient that already
  cleared. But metrics.csv shows it dip to 0.02 at the auto-resolve, then climb back higher
  and stay elevated (0.27 -> 0.41 -> 0.55); `pat-ai-toolcall-err` is surging negative
  (+540%, tool-dispatch failures aborting agent steps). The auto-resolve was the first flap
  of an escalating outage on a distinct root from P01. Must page.

Two feature-misleading items are the point of this scenario. **P21** breaks the
"auto_resolved => transient" heuristic: the disambiguator is the post-resolve metrics
trajectory (0.02 -> 0.27 -> 0.41 -> 0.55), not the alert field. **P22** breaks the
"rising + auto_resolved=null => real" heuristic: `gpu_warmup_mem_pct` rises 70 -> 82 -> 88
then plateaus at 89, holding under the 95 saturation line, and the
`inference-runner-2026.06.21-d` scale-up + model-preload deploy at 18:58 explains the raised
GPU memory floor. It is a steady state within limits, so suppress.

Everything else is noise expressed through the features: token-usage Warns and Spending Cap
alerts have 0% pattern delta and neutral sentiment (cost/budget signals); `[ignore]` log
monitors flap 16-19x/hr and self-clear in ~20s; CPU and GPU synthetic alerts auto-resolve in
tens of seconds with tiny pattern deltas. Two of the noise alerts wear loud SEV1 labels —
**P17** (Spending Cap) and **P19** (GPU mem blip) — but both flap and auto-resolve and sit on
flat/neutral patterns, so they are precision traps, not pages.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
