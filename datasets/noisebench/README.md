# NoiseBench dataset

NoiseBench measures one thing: **can a model tell a real incident from alert noise?**
It is an alert-triage benchmark, not a general SRE benchmark — no remediation, no live
systems. Each subdirectory is one **scenario**: a frozen window of telemetry plus a batch
of fired alerts ("pages") the model must triage into `page` vs `suppress`. The format is
the [Terminal-Bench](https://www.tbench.ai/) task layout, run by the
[Harbor](https://harborframework.com) harness.

## Scenario index

Seventeen scenarios in two groups:

- **Synthetic microservices app** (10) — a fictional e-commerce-style stack
  (payments, checkout, orders-db, api-gateway, …).
- **Reconstructions of representative production incident classes** (7) — all service,
  host, and identifier values are fictional stand-ins. These add a `monitor` field to
  each page and use realistic monitor names (e.g. `[ignore] Default Log Threshold
  Monitor` — the canonical flapper), representative failure classes (disk-pressure,
  queue-backlog, escalation-policy loop-back, CI/e2e-test-failure,
  application-warning-spike, AI-runtime errors), and standard Kubernetes event types
  (`DisruptionBlocked`, `Unconsolidatable`, `NodeNotReady`).

Every scenario contains **several real, page-class incidents** (3–5 of them) buried in
noise. A subset are `must_page` — suppressing any one of those is an automatic fail.
The remaining real incidents are quieter "recall traps" covered by `miss_budget`.

### Synthetic microservices app

| Scenario | Difficulty | Pages | Real | must_page | miss | F1 ≥ | What it stresses |
|---|---|---|---|---|---|---|---|
| `obvious-sev1-cluster` | easy | 16 | 3 | A01, A04 | 1 | 0.80 | Sanity check: two loud SEV1 roots + symptom dedup, plain flappers |
| `noisy-night-shift` | medium | 21 | 3 | P01, P12 | 1 | 0.80 | DB cascade, TLS cert expiry, OOM loop; collapse symptoms into roots |
| `cert-expiry-fanout` | medium | 20 | 3 | P01, P07, P14 | 0 | 0.80 | Cert-expiry fanout (4 alerts, 1 root), pool exhaustion, sustained backlog |
| `maintenance-window-masking` | medium | 18 | 3 | M03, M09 | 1 | 0.80 | Announced maintenance window masks a real out-of-scope outage and an in-scope replication stall |
| `region-failover-mixed` | medium | 22 | 3 | P06, P13 | 1 | 0.80 | Planned region failover churn vs the incidents the failover causes/exposes |
| `deploy-storm` | hard | 29 | 4 | D01, D26, D28 | 1 | 0.78 | Mass deploy window: churn that self-heals vs regressions that don't |
| `quiet-but-deadly` | hard | 20 | 4 | Q01, Q13, Q19 | 0 | 0.80 | Misleading severity tags: noisy SEV1s to suppress, quiet SEV2/SEV3 slow-burns to page |
| `slow-burn-saturation` | hard | 20 | 4 | P03, P09, P20 | 0 | 0.80 | Saturation trajectories: plateau-under-limit (benign) vs ratcheting floor (deadly) |
| `sev1-misconfigured-rule` | hard | 24 | 4 | P15, P18, P23 | 1 | 0.80 | A bad monitor rule tags 12 benign blips SEV1; severity/rule-source/fired_count all mislead |
| `mixed-triage-heavy` | hard | 32 | 5 | P01, P02, P10, P30 | 1 | 0.80 | Largest batch; every trap class combined, precision and recall stressed together |

### Reconstructed production incident classes

| Scenario | Difficulty | Pages | Real | must_page | miss | F1 ≥ | What it stresses |
|---|---|---|---|---|---|---|---|
| `warning-spike-transients` | medium | 14 | 3 | P01, P02 | 1 | 0.80 | Self-healing WARN bursts vs the leading edge of a real error cascade |
| `escalation-loopback-noise` | medium | 17 | 3 | P01, P16, P17 | 0 | 0.80 | PagerDuty escalation-policy loop-back and missed-ack meta-noise vs live 5xx incidents |
| `node-event-noise` | medium | 23 | 3 | P01, P21 | 1 | 0.80 | Normal Karpenter/PDB operational events vs `NodeNotReady` capacity loss and a memory-pressure eviction; a SEV1-tagged crashloop flapper vs a real SEV3 crashloop from the same monitor |
| `disk-pressure-flapper-storm` | medium | 24 | 3 | P01, P23, P24 | 0 | 0.80 | Real node disk-pressure evictions and a 100%-full PVC (tagged only SEV3) vs `[ignore]` log-threshold flappers (one mis-routed to SEV1) and a latched disk-warn alert |
| `ai-platform-alert-noise` | hard | 22 | 4 | P01, P05, P18, P21 | 0 | 0.80 | LLM token-usage / spending-cap cost noise vs real AI-runtime outages |
| `queue-backlog-vs-blip` | hard | 26 | 4 | P01, P20, P22, P25 | 0 | 0.78 | Self-draining queue/lag blips vs sustained backlogs, DLQ fill, and a ratcheting queue floor |
| `ci-e2e-test-noise` | hard | 28 | 4 | P01, P08, P27 | 0 | 0.80 | CI/staging/e2e test-failure noise vs real prod regressions, incl. a canary-fleet look-alike |

*Real = number of `page`-labeled alerts; miss = `miss_budget` (non-must-page real
incidents the model may drop and still pass, at an F1 cost).*

## Trap taxonomy

Scenarios reuse a common set of trap classes, escalating with difficulty:

- **Symptom collapse** — several pages share one root log pattern and a tight onset
  window: page the root, suppress the symptoms as duplicates.
- **Severity inversion** — SEV1-tagged flappers to suppress; quiet SEV2/SEV3 slow-burns
  that must page. The severity field is configured, not truth.
- **Innocent decoy deploy** — a deploy lands near incident onset without causing it,
  punishing "blame the latest deploy".
- **Real disguised as noise** — a genuine incident wearing a flapper's surface features
  (high `fired_count_last_1h`, short `auto_resolved_after_s`); only the `metrics.csv`
  trajectory (a ratcheting floor that never returns to baseline) betrays it. Usually
  `must_page`, so suppressing it is a cardinal fail.
- **Benign disguised as real** — a rising, never-auto-resolving metric that plateaus at
  a safe new steady state explained by a capacity/config deploy (heap resize, replica
  scale-up, canary error budget). Paging it costs precision.
- **Already-owned incident** — a page duplicating an entry in `incidents_open.json`
  must be suppressed; a human is engaged.
- **Latched alert** — an alert with `auto_resolved_after_s: null` whose underlying
  metric already returned to baseline (the monitor has no auto-clear). "Never resolved"
  is a property of the alert, not the incident; check `metrics.csv`.

In the harder scenarios the cheap single-field heuristics are deliberately defeated in
both directions ("rising + never-resolved ⇒ real" and "flapping + auto-resolved ⇒
noise" each have a counterexample); the only reliable disambiguator is the full metric
trajectory plus deploy context.

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
| `monitor` | (reconstructed scenarios only) the monitor that fired, e.g. `[ignore] Default Log Threshold Monitor`, `Platform API HTTP 5xx Error`, `NodeNotReady Error - K8s Event`, `OnCall AI Workflow Errors`, `LLM 24 Hour Token Usage`. The `[ignore]`-prefixed monitor is the canonical flapper |
| `metric` | the alerting metric (`error_rate`, `http_5xx_rate`, `cpu_pct`, `disk_usage_pct`, `p99_latency_ms`, `queue_depth`, `memory_pct`, `replication_lag_s`, plus scenario-specific variants like `queue_oldest_msg_age_s`, `workflow_500_rate`, `node_disk_pressure`, `token_usage_pct`, `open_fds`) |
| `severity` | `SEV1`..`SEV4` as configured on the alert — deliberately unreliable |
| `fired_at` | ISO-8601 UTC timestamp |
| `value` / `threshold` | observed value vs the alert threshold |
| `fired_count_last_1h` | how many times this same alert fired in the past hour (flap signal) |
| `auto_resolved_after_s` | seconds until it self-cleared, or `null` if it never did |
| `related_pattern` | id into `patterns.json` |
| `recent_deploy` | version id into `deploys.json`, or `null` |

### `metrics.csv`
`timestamp,service,metric,value` — baseline + incident-window samples for the services
that matter. The decisive evidence for the hard calls: whether a metric returned to
baseline, plateaued at a safe level, or keeps ratcheting toward a hard limit.

### `patterns.json`
Clustered log signatures: `pattern_id`, `signature`, `count`, `delta_vs_baseline_pct`,
`sentiment`. A surging negative pattern is a strong "this is real" signal; a flat
neutral pattern that fires every rotation is noise. In harder scenarios pattern features
are also spoofed (a real incident can share the flapper's pattern), so patterns alone
are not sufficient.

### `deploys.json`
Deploy events: `timestamp`, `service`, `commit_sha`, `version`. At least one is an
**innocent decoy** near incident onset — present to punish "blame the latest deploy".
Some are capacity/config changes that legitimately explain a higher-but-safe new
baseline.

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
  "miss_budget": 1,
  "positive_class": "page",
  "must_page": ["P01", "P12"],
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
   (`0` or `1` per scenario; see the index).
3. **F1 ≥ f1_threshold**.

Each scenario has 3–5 real incidents among 14–32 alerts, and correlated symptoms must
collapse into their roots, so the positive class is deliberately sparse. That makes the
benchmark unforgiving about over-paging: at full recall, even one or two false pages
drop F1 below threshold. That is the point — alert-noise reduction is precisely the
ability to wake a human for the real thing and *nothing else*. Secondary metrics
(precision, recall, false-suppress list, false-page list) are printed by the grader for
analysis but the pass/fail verdict is binary.

Alongside the binary verdict the grader emits a **graded reward** — `0.0` on a cardinal
(`must_page`) failure, otherwise F1 — as a `NOISEBENCH_METRICS` stdout line and, under
Harbor, `verifier/metrics.json`. It never changes pass/fail; the reporting scripts
(`scripts/process_results.py`, `scripts/gen_results.py`) use it to rank models on **mean
graded reward ± 95% CI** over attempts, which is far less noisy than counting binary
passes (a single flipped scenario moves a 17-scenario pass rate by ~2 points per
attempt, and near-misses and total failures stop looking identical).

## Adding a scenario

See [`../../tools/generate_scenario.py`](../../tools/generate_scenario.py) for the
fault-injection methodology and a skeleton generator.
