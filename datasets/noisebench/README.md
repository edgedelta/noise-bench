# NoiseBench dataset

Each subdirectory is one **scenario** — a frozen window of telemetry plus a batch of
fired alerts ("pages") the model must triage into `page` vs `suppress`. The format is the
[Terminal-Bench](https://www.tbench.ai/) task layout, run by the
[Harbor](https://harborframework.com) harness.

## Scenario index

Ten scenarios. The first three use a synthetic microservices app; the remaining seven are
**reconstructions of representative production incident classes** — all service, host, and
identifier values are fictional stand-ins. They use realistic service names, monitor names
(e.g. `[ignore] Default Log Threshold Monitor` — the canonical flapper),
representative failure classes (disk-pressure, queue-backlog, escalation-policy loop-back,
CI/e2e-test-failure, application-warning-spike, AI-runtime errors), and standard Kubernetes
event types (`DisruptionBlocked`, `Unconsolidatable`, `NodeNotReady`). Each reconstructed
scenario has exactly one real, must-page incident that cannot be suppressed.

| Scenario | Tier | Pages | F1 ≥ | Incident class (fictional reconstruction) | must_page |
|---|---|---|---|---|---|
| `noisy-night-shift` | medium | 20 | 0.80 | synthetic (DB cascade) | P01 |
| `deploy-storm` | hard | 25 | 0.78 | synthetic (deploy regression) | D01 |
| `quiet-but-deadly` | medium | 12 | 0.80 | synthetic (slow-burn) | — |
| `disk-pressure-flapper-storm` | medium | 22 | 0.80 | Kubernetes node disk pressure (x6) — real eviction risk vs `[ignore]` log-threshold flappers + self-resolving disk warns | P01 |
| `escalation-loopback-noise` | medium | 16 | 0.80 | PagerDuty escalation-policy loop-back + missed-ack — meta-noise vs a real missed-ack on a live `Platform API 5xx` | P01 |
| `ci-e2e-test-noise` | hard | 24 | 0.78 | CI / e2e test failures triggering incidents — test-env noise vs a real `web-app` prod regression | P01 |
| `warning-spike-transients` | medium | 14 | 0.80 | Transient application warning spikes — self-healing WARN bursts vs the leading edge of a real `http-receiver` error cascade | P01 |
| `ai-platform-alert-noise` | hard | 20 | 0.78 | AI-platform monitors — `LLM 24h Token Usage` + `Spending Cap` cost noise vs a real `ai-agent-svc` outage (`OnCall AI Workflow Errors`) | P01 |
| `queue-backlog-vs-blip` | hard | 20 | 0.78 | Queue backlog degrades ingestion (x2) — self-draining blips vs a sustained backlog on `metric-ingest-queue-1` | P01 |
| `node-event-noise` | medium | 18 | 0.80 | Kubernetes events — normal Karpenter/PDB operational events vs a real `NodeNotReady` capacity drop | P01 |

Each reconstructed scenario also collapses one or more **downstream symptom** pages into its real
incident (same root log pattern + tight onset window) — suppress the symptoms, page the root.

## Scenario directory layout

```
<scenario>/
  task.toml                       # Terminal-Bench task metadata
  instruction.md                  # the prompt the model sees
  environment/
    Dockerfile                    # python:3.12-slim + jq/grep; COPYs workdir/ into /workdir
    workdir/                      # the telemetry the model gets (copied to /workdir at runtime)
      pages.json
      metrics.csv
      patterns.json
      deploys.json
      incidents_open.json
  solution/
    solve.sh                      # ORACLE: writes the known-correct /workdir/triage.json
    triage.json                   # the oracle answer (what solve.sh emits)
  tests/
    test.sh                       # installs uv + pytest, runs test_outputs.py, writes reward.txt
    test_outputs.py               # the grader (loads triage.json + ground_truth.json)
    ground_truth.json             # per-page labels + must_page + thresholds (verifier-only)
```

`tests/` is injected only at verification time, so the model never sees `ground_truth.json`.

## Input data the model gets (`/workdir/`)

### `pages.json` — the alert batch
A JSON list. Each page:

| field | meaning |
|-------|---------|
| `id` | page id, e.g. `P01` |
| `service` | service that alerted |
| `monitor` | (reconstructed scenarios) the monitor that fired, e.g. `[ignore] Default Log Threshold Monitor`, `Platform API HTTP 5xx Error`, `NodeNotReady Error - K8s Event`, `OnCall AI Workflow Errors`, `LLM 24 Hour Token Usage`. The `[ignore]`-prefixed monitor is the canonical flapper |
| `metric` | the alerting metric (`error_rate`, `http_5xx_rate`, `cpu_pct`, `disk_usage_pct`, `p99_latency_ms`, `queue_depth`, `memory_pct`, `replication_lag_s`, plus scenario-specific variants like `queue_oldest_msg_age_s`, `workflow_500_rate`, `node_disk_pressure`, `token_usage_pct`) |
| `severity` | `SEV1`..`SEV4` as configured on the alert |
| `fired_at` | ISO-8601 UTC timestamp |
| `value` / `threshold` | observed value vs the alert threshold |
| `fired_count_last_1h` | how many times this same alert fired in the past hour (flap signal) |
| `auto_resolved_after_s` | seconds until it self-cleared, or `null` if it never did |
| `related_pattern` | id into `patterns.json` |
| `recent_deploy` | version id into `deploys.json`, or `null` |

### `metrics.csv`
`timestamp,service,metric,value` — baseline + incident-window samples for the services
that matter. Used to confirm whether a metric actually returned to baseline.

### `patterns.json`
Clustered log signatures: `pattern_id`, `signature`, `count`, `delta_vs_baseline_pct`,
`sentiment`. A surging negative pattern is the strongest "this is real" signal; a flat
neutral pattern that fires every rotation is noise.

### `deploys.json`
Deploy events: `timestamp`, `service`, `commit_sha`, `version`. At least one is an
**innocent decoy** near incident onset — present to punish "blame the latest deploy".

### `incidents_open.json`
Incidents a human is already working: `incident_id`, `service`, `metric`, `opened_at`,
`status`, `owner`, `related_pattern`, `summary`. A page that duplicates one of these
should be **suppressed** (a human is already engaged).

## Output the model must write (`/workdir/`)

`triage.json`:
```json
{ "decisions": [ { "page_id": "P01", "decision": "page", "reason": "..." } ] }
```
plus a free-form `reasoning.md`.

## Ground truth (`tests/ground_truth.json`)

```json
{
  "scenario": "noisy-night-shift",
  "f1_threshold": 0.80,
  "miss_budget": 0,
  "positive_class": "page",
  "must_page": ["P01"],
  "labels":   { "P01": "page", "P02": "suppress", ... },
  "rationale":{ "P01": "why this is the call", ... },
  "notes": "..."
}
```

## How scoring works

Positive class = `page`. The grader computes precision / recall / **F1** against `labels`
and enforces, in order:

1. **Cardinal rule** — every id in `must_page` MUST be `page`. Suppressing one is an
   automatic **reward 0**, regardless of F1. (Missing a real SEV1 is the cardinal sin.)
2. **miss_budget** — at most this many *non-must-page* real incidents may be missed
   (default `0`).
3. **F1 ≥ f1_threshold**.

Because each scenario has a single real incident that should collapse to **one** page,
the positive class is deliberately sparse. That makes the benchmark unforgiving about
over-paging: at full recall, even one false page drops F1 below threshold. That is the
point — alert-noise reduction is precisely the ability to wake a human for the real thing
and *nothing else*. Secondary metrics (precision, recall, false-suppress list, false-page
list) are printed by the grader for analysis but the reward is binary (pass/fail).

## Adding a scenario

See [`../../tools/generate_scenario.py`](../../tools/generate_scenario.py) for the
fault-injection methodology and a skeleton generator.
