# PageBench

### Can AI tell a real incident from alert noise?

It's 2am. Twenty alerts just fired. One of them is a database melting down and taking
checkout with it. The other nineteen are a disk-usage alert that flaps every four minutes,
two CPU blips that healed before you finished reading them, a duplicate of a ticket someone
already owns, and a deploy that fixed itself. **PageBench** asks a frontier LLM to do what
your on-call engineer does half-asleep: decide who to wake up — and, just as important, who
to leave alone.

This is a benchmark for **models, not products**. Every model gets the same telemetry, the
same tools, the same prompt. We measure the reasoning.

---

## The question

Modern observability stacks don't have a data problem — they have a *paging* problem. Alerts
fire constantly. Most are noise: flaps, transients, deploy churn, duplicates of incidents
already being worked. A few are real and need a human *now*. The skill that matters is
triage: separating the one real incident from the pile of look-alikes — without missing the
real one, and without waking someone for a blip.

PageBench gives a model a batch of fired pages plus the context a good engineer would pull —
recent metric values, clustered log patterns, deploy history, whether the alert auto-resolved,
how often it has fired this hour, and which incidents are already open — and asks it to label
each page **`page`** (wake a human) or **`suppress`** (noise).

## What the benchmark measures

For each page, the model decides `page` vs `suppress`. We score the positive class (`page`)
with precision / recall / **F1**, under one non-negotiable rule:

- **You may not suppress a real incident.** Each scenario contains at least one real,
  high-severity incident that *must* be paged. Suppress it and you score **zero**, no matter
  how clean the rest of your answer is. Missing a real SEV1 is the cardinal sin of on-call.
- **Over-paging is penalized.** Every piece of noise you page costs precision. Because a real
  incident should collapse to a *single* page, the bar is unforgiving: at full recall, one
  false page already drops you below threshold.

It rewards exactly one behavior: wake a human for the real thing, and nothing else.

## How it works

PageBench uses the [Terminal-Bench](https://www.tbench.ai/) task format, run by the
[Harbor](https://harborframework.com) harness with the default **`terminus-2`** agent. We
ship only the **tasks + datasets + scoring** — the harness and the models are external. Every
model is dropped into an identical Docker sandbox with the telemetry under `/workdir/` and
standard shell tools (`jq`, `grep`, `cat`, …), and must write its decisions to
`/workdir/triage.json`. There is no product in the loop; this is a pure reasoning eval.

EdgeDelta's query language is **CQL** (field equality like `severity:"SEV1"`, boolean
`AND`/`OR`/negation, numeric comparisons like `@value > 400`; no regex, no mid-string
wildcards). The shipped data is plain JSON/CSV so the agent can reason with `jq`/`grep` as
though running CQL filters.

## Running it

Requires [Harbor](https://harborframework.com) (`uv tool install harbor`), Docker, and an
[OpenRouter](https://openrouter.ai/) key (or your own model credentials).

```bash
git clone https://github.com/edgedelta/page-bench.git
cd page-bench

# put OPENROUTER_API_KEY=... in .env
source .env

# all scenarios, several models, 3 attempts each
uv run harbor run -c configs/all-models-docker.yaml

# quick single-model / single-scenario smoke test
uv run harbor run -c configs/smoke-docker.yaml
```

Summarise a run into a markdown table:

```bash
uv run scripts/process_results.py jobs/<run-dir>
```

Inspect agent trajectories with `harbor view jobs`.

## Task format

Each scenario under [`datasets/pagebench/`](datasets/pagebench/) is a Terminal-Bench task:
`task.toml`, `instruction.md`, `environment/Dockerfile` (+ the frozen telemetry in
`environment/workdir/`), `solution/solve.sh` (an oracle answer used to validate the grader),
and `tests/` (the grader `test_outputs.py` + verifier-only `ground_truth.json`). See the
[dataset README](datasets/pagebench/README.md) for the data schema and scoring details.

## Difficulty tiers

The first three scenarios use a synthetic microservices app. The remaining seven are
**reconstructions of representative production incident classes** — all service, host,
monitor, and identifier values are fictional stand-ins. They use realistic service names
(`http-receiver`, `metric-ingestor-1`, `ai-agent-svc`, …), monitor
names (`[ignore] Default Log Threshold Monitor`, `Platform API HTTP 5xx Error`, `NodeNotReady
Error - K8s Event`, `OnCall AI Workflow Errors`, `LLM 24 Hour Token Usage`, …), and standard
Kubernetes event types (`DisruptionBlocked`, `Unconsolidatable`, `NodeNotReady`). See the
[dataset README](datasets/pagebench/README.md) for the per-scenario notes.

| Scenario | Tier | Pages | The trap |
|---|---|---|---|
| [`noisy-night-shift`](datasets/pagebench/noisy-night-shift/) | medium | 20 | A real DB cascade fires 4 correlated pages — collapse them to **one**. The rest is flaps, transients, a duplicate of an open incident, and a self-healed deploy. |
| [`deploy-storm`](datasets/pagebench/deploy-storm/) | hard | 25 | Ten services deployed at once; almost all the churn self-heals. **One** deploy shipped a real regression that doesn't. Over-suppressing kills you. |
| [`quiet-but-deadly`](datasets/pagebench/quiet-but-deadly/) | medium | 12 | Mostly low-grade noise, plus a quiet slow-burn incident with **no deploy to blame**. Tests the "blame the deploy" and "ignore the quiet one" biases. |
| [`disk-pressure-flapper-storm`](datasets/pagebench/disk-pressure-flapper-storm/) | medium | 22 | The `[ignore] Default Log Threshold Monitor` flaps everywhere and disk warnings self-resolve on rotation. **One** node crosses into real `DiskPressure` eviction risk. |
| [`escalation-loopback-noise`](datasets/pagebench/escalation-loopback-noise/) | medium | 16 | PagerDuty escalation-policy meta-noise (loop-back to the same responder, missed-ack reminders on transient staging CI). **One** genuine missed-ack on a live SEV1 `Platform API 5xx`. |
| [`ci-e2e-test-noise`](datasets/pagebench/ci-e2e-test-noise/) | hard | 24 | CircleCI / Playwright e2e failures wired into PagerDuty as incidents — test-env noise that shouldn't page prod. **One** e2e failure reflects a real `web-app` regression. |
| [`warning-spike-transients`](datasets/pagebench/warning-spike-transients/) | medium | 14 | WARN-level spikes that self-heal in seconds (incl. the classic Workflow `runMainLoop` bursts). **One** is the leading edge of a real error cascade on `http-receiver`. |
| [`ai-platform-alert-noise`](datasets/pagebench/ai-platform-alert-noise/) | hard | 20 | `LLM 24 Hour Token Usage` Warns + `Spending Cap` budget alerts — cost noise, not outages. **One** real `ai-agent-svc` outage via `OnCall AI Workflow Errors`. |
| [`queue-backlog-vs-blip`](datasets/pagebench/queue-backlog-vs-blip/) | hard | 20 | Transient queue-depth blips that drain on their own. **One** sustained, non-draining backlog on `metric-ingest-queue-1` blocking the write path. |
| [`node-event-noise`](datasets/pagebench/node-event-noise/) | medium | 18 | Normal Karpenter/PDB operational events (`Pdb prevents pod evictions`, `SpotToSpotConsolidation disabled`, `Unconsolidatable`, `store validated`). **One** real `NodeNotReady` drops capacity. |

## Leaderboard

Frozen run: **17 scenarios × 4 models × 3 attempts = 204 trials**, Harbor `terminus-2` over
OpenRouter, 2026-06-28. A trial **passes** only if it pages every must-page incident (cardinal —
suppressing a real SEV1 = reward 0), hits F1 ≥ threshold (positive class = page), and misses no
more real incidents than the miss budget. Pass rate = trials passed / 51.

| Model | Pass rate | easy | medium | hard |
|---|---|---:|-------:|-----:|
| gpt-5.2-codex   | **80%** (41/51) | 100% | 100% | 58% |
| claude-opus-4.6 | **78%** (40/51) | 100% | 100% | 54% |
| kimi-k2.5       | **75%** (38/51) | 100% | 100% | 46% |
| gemini-2.5-pro  | **51%** (26/51) | 100% | 88%  | 8%  |

The split lives in the **hard** tier, where the alert *features mislead*: a real incident that
auto-resolved once (or flaps like noise) but whose metric ratchets toward a ceiling, paired with a
benign alert whose metric rises but plateaus at a safe new normal after a capacity change. Getting
these right needs cross-referencing the metric trajectory + deploy context, not reading a single
field. `slow-burn-saturation` is failed by **every** model on **every** attempt; gemini-2.5-pro
collapses to 8% on the hard tier. Re-score any published trajectory yourself, no API key needed:
`uv run scripts/process_results.py jobs/<run>`.

We expect models to do **badly** here, especially on `deploy-storm` (waving the whole storm
away as "just deploys"), `ci-e2e-test-noise` (telling a real prod regression from flaky test
failures), and `ai-platform-alert-noise` (separating a real AI-runtime outage from LLM
token-usage and spending-cap cost noise). If your model tops this chart, it earned it.

## How scenarios are generated

Each scenario is a frozen telemetry window built by fault injection:

1. Run a microservices demo app under steady synthetic load.
2. Inject one real fault tied to a specific **git commit** (the culprit) — a connection leak,
   a bad pool client, a slow upstream — and deploy it.
3. Let it propagate; capture the pages that fire, the metrics, the clustered log patterns, the
   deploy log, and any already-open incidents.
4. Freeze a small window of that telemetry.
5. Inject realistic **distractors**: chronic flappers, sub-minute self-healing transients,
   downstream symptoms of the real incident (to test correlation/dedup), an innocent deploy
   near onset (to punish "blame the latest deploy"), and a duplicate of an already-open
   incident. Timestamps are kept internally consistent — onset always *after* the culprit
   deploy, with the innocent deploy placed near onset as bait.
6. Emit `ground_truth.json`: per-page `page`/`suppress` labels plus the `must_page` list.

In v1 the root-cause label space is **git commits** (code changes); feature-flag changes
appear only as decoys. The pipeline and a skeleton generator live in
[`tools/generate_scenario.py`](tools/generate_scenario.py).

## Building your own scenarios

```bash
uv run tools/generate_scenario.py weekend-cron-storm --noise 18 --difficulty hard
```

This emits a runnable scenario skeleton (one real incident + injected noise, all data files +
ground truth). Copy `task.toml` / `instruction.md` / `environment/Dockerfile` / `tests/` /
`solution/solve.sh` from an existing scenario, then replace the synthetic data with a captured
window. Validate that your oracle (`solution/solve.sh`) passes your grader before publishing.

## Why we built this

At [Edge Delta](https://edgedelta.com) we spend our days on the on-call-burden problem:
turning a firehose of alerts into the handful that deserve a human. PageBench is our attempt to
measure that reasoning honestly and in the open — for any model, with no product in the loop.
EdgeDelta isn't on the leaderboard; the benchmark is neutral.

## License

Apache-2.0. See [LICENSE](LICENSE).
