#!/bin/bash
# Oracle solution: write the known-correct triage decisions for cert-expiry-fanout.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "cert-gateway tls_handshake_failure_rate 0.97 vs 0.02, never auto-resolved, pat-tls-cert-expired surges from ~zero baseline (delta 9999%). Root of the cert-expiry fanout. SEV1."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "payments 5xx sharing pat-tls-cert-expired, onset ~45s after P01. Symptom of the cert incident; collapse into P01."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "GC-pause CPU blip auto-resolved in 37s; metric back to 46 the next minute."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Disk flapper: 16 fires/hr around the 85% threshold, self-clears in 21s; metric returns to 82."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "api-edge handshake failures sharing pat-tls-cert-expired, onset ~80s after P01. Symptom of the cert incident."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "frontend 5xx bump during fe-2026.05.20-c rollout, auto-resolved in 44s; metric back to 0.002. Deploy transient."
    },
    {
      "page_id": "P07",
      "decision": "page",
      "reason": "orders-db db_pool_wait_ms 8400 vs 250, rose 40->1900->8400->9600 with no recovery, pat-db-pool-exhausted surging 1800%. Independent SEV1 connection-pool exhaustion."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "GC-pause CPU blip auto-resolved in 29s. Self-cleared."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "checkout db_pool_wait_ms sharing pat-db-pool-exhausted, onset ~70s after P07. Symptom of the DB pool incident; collapse into P07."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Disk flapper (see P04), oscillation cleared in 19s."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "webhook-dispatcher 5xx sharing pat-tls-cert-expired, same cert root and onset window. Symptom of the cert incident."
    },
    {
      "page_id": "P12",
      "decision": "suppress",
      "reason": "Cold-cache latency blip, self-resolved in 26s; metric back to 540."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "notifications queue marginally over threshold during batch drain, cleared in 17s; metric back to 3100."
    },
    {
      "page_id": "P14",
      "decision": "page",
      "reason": "ingest-pipeline queue_depth 41000 vs 8000, monotonic rise 6200->41000->72000->98000 with no recovery, pat-ingest-backlog growing. Independent sustained backlog. SEV1."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "Cold-cache latency blip, recovered in 23s; metric back to 610."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "Post-deploy CPU settle during fe-2026.05.20-c, auto-resolved in 35s; metric back to 49. Deploy transient."
    },
    {
      "page_id": "P17",
      "decision": "suppress",
      "reason": "media-encoder queue matches already-open INC-9142 (pat-encoder-backlog); oncall-media is engaged and scaling out. Metric flat-to-falling. Already owned."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "Disk flapper (see P04), cleared in 20s."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "GC-pause CPU blip auto-resolved in 31s; metric back to 48."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "notifications 5xx flicker barely over threshold, self-cleared in 18s; metric back to 0.004."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — cert-expiry-fanout

Three page-class incidents are buried in 20 alerts; everything else is noise.

1. **Cert-expiry fanout** — P01 (cert-gateway tls_handshake_failure_rate 0.97,
   pat-tls-cert-expired surging from ~zero baseline, never resolves) is the SEV1 root.
   P02 (payments 5xx), P05 (api-edge handshake), P11 (webhook 5xx) share the same
   pat-tls-cert-expired and fire within a ~2-minute window downstream -> collapse into
   P01, suppress the three symptoms. Paging all four would over-page one incident.
2. **DB connection-pool exhaustion** — P07 (orders-db db_pool_wait_ms 8400 -> 9600,
   pat-db-pool-exhausted, no recovery) is an independent SEV1. P09 (checkout pool wait,
   same pattern, ~70s later) is the downstream symptom -> suppress.
3. **Sustained ingest backlog** — P14 (ingest-pipeline queue_depth rising
   6200 -> 41000 -> 72000 -> 98000, never resolves) is an independent SEV1.

All remaining pages are noise: disk flappers (P04/P10/P18, 16 fires/hr, clear in ~20s),
sub-minute auto-resolved GC/cold-cache/batch transients (P03/P08/P12/P13/P15/P19/P20),
deploy-correlated rollout blips that recovered (P06/P16), and P17 which duplicates
already-open INC-9142 (oncall-media already engaged).

Page the three roots (P01, P07, P14); suppress the rest.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
