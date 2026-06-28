#!/bin/bash
# Oracle solution: write the known-correct triage decisions for noisy-night-shift.
# Used to validate the grader (this answer must pass tests/test_outputs.py).
set -euo pipefail

cat > /workdir/triage.json <<'JSON'
{
  "decisions": [
    {
      "page_id": "P01",
      "decision": "page",
      "reason": "Primary replication lag 420s and still climbing (510s at 02:40), never auto-resolved, connection-refused pattern surging 14x baseline. Root of the DB cascade. SEV1."
    },
    {
      "page_id": "P02",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (same pat-db-conn-refused, onset 40s after the DB page). Collapse into the DB incident."
    },
    {
      "page_id": "P03",
      "decision": "suppress",
      "reason": "Downstream symptom of P01 (DB-bound query latency, same root pattern). Duplicate of the DB cascade."
    },
    {
      "page_id": "P04",
      "decision": "suppress",
      "reason": "Downstream symptom of P01, same root pattern. Part of the one DB incident."
    },
    {
      "page_id": "P05",
      "decision": "suppress",
      "reason": "15 fires/hr, oscillates around the 85% threshold and self-clears in ~22s on log rotation; metric returns to 83."
    },
    {
      "page_id": "P06",
      "decision": "suppress",
      "reason": "CPU blip auto-resolved in 41s (GC pause); metric back to 44 the next minute."
    },
    {
      "page_id": "P07",
      "decision": "suppress",
      "reason": "CPU blip auto-resolved in 28s. Self-cleared."
    },
    {
      "page_id": "P08",
      "decision": "suppress",
      "reason": "Matches already-open INC-8800 (billing queue backlog) in incidents_open.json. A human is already engaged."
    },
    {
      "page_id": "P09",
      "decision": "suppress",
      "reason": "5xx bump during fe-2026.03.12-a rollout, auto-resolved in 47s; metric back to 0.003. Deploy transient."
    },
    {
      "page_id": "P10",
      "decision": "suppress",
      "reason": "Marginally over threshold during batch drain, cleared in 19s. Routine."
    },
    {
      "page_id": "P11",
      "decision": "suppress",
      "reason": "Cold-cache latency blip, self-resolved in 33s."
    },
    {
      "page_id": "P12",
      "decision": "page",
      "reason": "Auth login failures 0.92 vs 0.05 threshold, never auto-resolved, still 0.96 at 02:30; pat-tls-cert-expired surges from zero baseline. Expired TLS cert blocking logins; no deploy to blame. SEV1."
    },
    {
      "page_id": "P13",
      "decision": "suppress",
      "reason": "Same disk flapper as P05, another oscillation (cleared in 18s)."
    },
    {
      "page_id": "P14",
      "decision": "suppress",
      "reason": "Downstream symptom of P12: api-gateway 401 surge sharing pat-tls-cert-expired, onset within ~80s. Collapse into the auth cert incident."
    },
    {
      "page_id": "P15",
      "decision": "suppress",
      "reason": "Cold-cache latency blip, recovered in 24s."
    },
    {
      "page_id": "P16",
      "decision": "suppress",
      "reason": "Post-deploy CPU settle (fe-2026.03.12-a), auto-resolved in 38s."
    },
    {
      "page_id": "P17",
      "decision": "page",
      "reason": "session-store memory pinned at 99% (rose 71->99, no recovery), pat-oomkill-restart, never auto-resolved. Real OOM/restart loop on a stateful worker. Root of the OOM incident."
    },
    {
      "page_id": "P18",
      "decision": "suppress",
      "reason": "Minor 5xx flicker, self-cleared in 21s."
    },
    {
      "page_id": "P19",
      "decision": "suppress",
      "reason": "CPU blip auto-resolved in 30s."
    },
    {
      "page_id": "P20",
      "decision": "suppress",
      "reason": "Disk flapper oscillation (see P05), cleared in 20s."
    },
    {
      "page_id": "P21",
      "decision": "suppress",
      "reason": "Downstream symptom of P17: session-store pod_restart_count climbing, same pat-oomkill-restart root and onset window. Duplicate of the OOM incident."
    }
  ]
}
JSON

cat > /workdir/reasoning.md <<'MD'
# Oracle reasoning — noisy-night-shift

Three independent real incidents are buried in the batch; everything else is noise.

1. **DB cascade** — P01 (postgres replication lag 420s -> 510s, pat-db-conn-refused
   surging 14x, never resolves) is the root SEV1. P02/P03/P04 share the same root
   pattern and fire within ~90s downstream -> suppress as duplicates of the one incident.
2. **Auth TLS cert expiry** — P12 (auth login_failure_rate 0.92, pat-tls-cert-expired
   from ~zero baseline, never resolves) is an independent SEV1. P14 (api-gateway 401
   surge, same pattern, ~80s later) is the downstream symptom -> suppress.
3. **session-store OOM/restart loop** — P17 (memory pinned 99%, rose 71->99 with no
   recovery, pat-oomkill-restart) is a real SEV2 on a stateful worker. P21 (pod restart
   count climbing, same root pattern) is the symptom -> suppress.

All remaining pages are noise: disk flappers (P05/P13/P20, ~15 fires/hr, clear in <25s),
sub-minute auto-resolved CPU/latency/queue transients (P06/P07/P10/P11/P15/P16/P18/P19),
a self-healed deploy blip (P09), and a duplicate of already-open INC-8800 (P08).

Page the three roots (P01, P12, P17); suppress the rest.

See `tests/ground_truth.json` rationale for the per-page justification.
MD

echo "wrote /workdir/triage.json and /workdir/reasoning.md"
