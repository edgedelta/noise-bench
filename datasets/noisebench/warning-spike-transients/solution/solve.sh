#!/bin/bash
# Oracle solution: write the known-correct triage decisions for warning-spike-transients.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "http-receiver warn_log_rate is the leading edge of a real cascade: 340 then 510 vs threshold 100, never auto-resolved, pat-httprecv-cascade surging 640% negative into HTTP 500s and still live at 13:41. Keeps climbing instead of returning to its 40 baseline. Cardinal must-page."
    },
    {
      "page_id": "P02",
      "decision": "page",
      "reason": "edge-ingest-gateway http_5xx_rate 0.31 vs 0.05 and climbing 0.31 -> 0.38 -> 0.44, never auto-resolved, pat-edgegw-5xx surging 920% negative. Sustained SEV1 5xx outage; the deploy 4m earlier does not exonerate it because the rate keeps rising. Cardinal must-page."
    },
    {
      "page_id": "P03",
      "decision": "page",
      "reason": "olapdb-server mem_used_pct climbs 71 -> 88 -> 92 -> 95 -> 97 over two hours, never auto-resolves, pat-olap-mem-climb negative and still live. Slow no-deploy saturation that looks quiet (SEV3, one fire) but never recovers and will OOM. Real."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "transformer error_rate shares pat-httprecv-cascade with P01 and fires 13min later on the same http-receiver failure path. Downstream symptom of the P01 cascade; collapse into it."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "inference-runner warn 180 dropped to 35 one minute later; auto_resolved in 45s, pat-workflow-warn-transient neutral 12%. Self-cleared transient."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "Platform API warn on an [ignore]-prefixed monitor, fired_count 8, auto_resolved in 30s, pat-warn-transient neutral 6%. Chronic flapper noise."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "workflow-engine warn 210 dropped to 42 one minute later; auto_resolved in 52s, pat-workflow-warn-transient neutral. Self-cleared transient."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "transformer warn auto_resolved in 38s, pat-warn-transient neutral 6%. Returned to baseline. Noise."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "olapdb-tso warn on an [ignore]-prefixed monitor, fired_count 9, auto_resolved in 27s. Chronic flapper. Noise."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "inference-runner warn auto_resolved in 41s, pat-workflow-warn-transient neutral. Self-cleared transient."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "kafka-metric-ingestor warn auto_resolved in 33s, pat-warn-transient neutral. Noise."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "Platform API warn on an [ignore]-prefixed monitor, fired_count 8, auto_resolved in 29s. Chronic flapper. Noise."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "dashboard-svc warn auto_resolved in 22s, pat-warn-transient neutral. Noise."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "auditlog-ingestor warn on an [ignore]-prefixed monitor, fired_count 7, auto_resolved in 31s. Chronic flapper. Noise."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — warning-spike-transients

Three real, page-worthy incidents are buried in warn-spike churn:

- **P01 (must-page)** — http-receiver warn_log_rate is the leading edge of a real cascade.
  It rises 340 -> 510 (baseline 40), never auto-resolves, and pat-httprecv-cascade surges
  640% negative as warns escalate into HTTP 500s (still live at 13:41). Unlike the transient
  warn spikes, it does NOT return to baseline.
- **P02 (must-page)** — edge-ingest-gateway http_5xx_rate 0.31 vs 0.05 and climbing
  (0.31 -> 0.38 -> 0.44), never auto-resolved, pat-edgegw-5xx 920% negative. A sustained
  SEV1 5xx outage. The edge-ingest-gateway deploy 4 minutes earlier is a tempting culprit but
  does not exonerate the alert: the rate keeps rising, so it is a real regression, not a
  settling deploy blip.
- **P03 (recall trap)** — olapdb-server mem_used_pct climbs 71 -> 88 -> 92 -> 95 -> 97 over
  two hours and never auto-resolves. It looks benign (SEV3, single fire, no deploy) but the
  monotonic saturation trend and live negative pattern mean it is heading for an OOM. A
  conservative triager who keys on severity alone misses it.

**P04** is the downstream transformer error symptom of the P01 cascade (same
pat-httprecv-cascade, +13min) and collapses into P01.

Everything else (P05-P14) is self-clearing warn-spike noise: each auto-resolves within
~22-52s, the metric snaps back to baseline one sample later, the patterns are neutral with
single-digit delta, and several fire on [ignore]-prefixed flapper monitors with high
fired_count. The distinguisher between P01 and this churn is not severity — it is
auto_resolved_after_s, fired_count, pattern sentiment/delta, and whether the metric trend
returns to baseline.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
