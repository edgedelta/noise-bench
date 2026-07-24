# NoiseBench

### Can AI tell a real incident from alert noise?

It's 2am. Twenty-odd alerts just fired. A few are real — a database melting down and taking
checkout with it, an auth cert that expired, a queue quietly saturating toward an outage. The
rest are noise: a disk-usage alert that flaps every four minutes, two CPU blips that healed
before you finished reading them, a duplicate of a ticket someone already owns, and a deploy
that fixed itself. **NoiseBench** asks a frontier LLM to do what your on-call engineer does
half-asleep: decide who to wake up — catching *every* real incident without drowning in the
noise. Miss one real page and you've failed, no matter how clean the rest of your triage.

This is a benchmark for **models, not products**. Every model gets the same telemetry, the
same tools, the same prompt. We measure the reasoning.

---

## The question

Modern observability stacks don't have a data problem — they have a *paging* problem. Alerts
fire constantly. Most are noise: flaps, transients, deploy churn, duplicates of incidents
already being worked. A few are real and need a human *now*. The skill that matters is
triage: separating the one real incident from the pile of look-alikes — without missing the
real one, and without waking someone for a blip.

NoiseBench gives a model a batch of fired pages plus the context a good engineer would pull —
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

NoiseBench uses the [Terminal-Bench](https://www.tbench.ai/) task format, run by the
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
git clone https://github.com/edgedelta/noise-bench.git
cd noise-bench

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

Each scenario under [`datasets/noisebench/`](datasets/noisebench/) is a Terminal-Bench task:
`task.toml`, `instruction.md`, `environment/Dockerfile` (+ the frozen telemetry in
`environment/workdir/`), `solution/solve.sh` (an oracle answer used to validate the grader),
and `tests/` (the grader `test_outputs.py` + verifier-only `ground_truth.json`). See the
[dataset README](datasets/noisebench/README.md) for the data schema and scoring details.

## Difficulty tiers

Seventeen scenarios. Ten use a synthetic microservices app; the other seven are
**reconstructions of representative production incident classes** — all service, host,
monitor, and identifier values are fictional stand-ins. They use realistic service names
(`http-receiver`, `metric-ingestor-1`, `ai-agent-svc`, …), monitor
names (`[ignore] Default Log Threshold Monitor`, `Platform API HTTP 5xx Error`, `NodeNotReady
Error - K8s Event`, `OnCall AI Workflow Errors`, `LLM 24 Hour Token Usage`, …), and standard
Kubernetes event types (`DisruptionBlocked`, `Unconsolidatable`, `NodeNotReady`). Every
scenario hides 3–5 real incidents in the noise. See the
[dataset README](datasets/noisebench/README.md) for the data schema, per-scenario notes, and
the full trap taxonomy.

| Scenario | Tier | Pages | The trap |
|---|---|---|---|
| [`obvious-sev1-cluster`](datasets/noisebench/obvious-sev1-cluster/) | easy | 16 | Sanity check: two loud SEV1 roots plus their downstream symptoms — collapse and page the roots. |
| [`noisy-night-shift`](datasets/noisebench/noisy-night-shift/) | medium | 21 | A DB cascade fires 4 correlated pages — collapse them to **one**; plus a cert expiry, an OOM loop, and the usual flaps and transients. |
| [`cert-expiry-fanout`](datasets/noisebench/cert-expiry-fanout/) | medium | 20 | One expired cert fans out to four alerts in two minutes; page the root once, not four times. |
| [`maintenance-window-masking`](datasets/noisebench/maintenance-window-masking/) | medium | 18 | An announced maintenance window explains ~12 alerts — but not the out-of-scope CDN outage, nor the replication stall exceeding the expected blast. |
| [`region-failover-mixed`](datasets/noisebench/region-failover-mixed/) | medium | 22 | Planned region-failover churn self-heals; the shifted traffic saturates one region's payments and replication — those don't. |
| [`warning-spike-transients`](datasets/noisebench/warning-spike-transients/) | medium | 14 | WARN-level spikes that self-heal in seconds. One is the leading edge of a real error cascade on `http-receiver`. |
| [`escalation-loopback-noise`](datasets/noisebench/escalation-loopback-noise/) | medium | 17 | PagerDuty escalation-policy meta-noise (loop-backs, missed-ack reminders on staging CI) vs missed-acks on genuinely live incidents. |
| [`node-event-noise`](datasets/noisebench/node-event-noise/) | medium | 23 | Normal Karpenter/PDB operational events (`Pdb prevents pod evictions`, `Unconsolidatable`, …) vs a real `NodeNotReady` capacity loss and a memory-pressure eviction. A SEV1-tagged crashloop flapper sits next to a real crashloop tagged only SEV3. |
| [`disk-pressure-flapper-storm`](datasets/noisebench/disk-pressure-flapper-storm/) | medium | 24 | The `[ignore] Default Log Threshold Monitor` flaps everywhere (one mis-routed to SEV1) and disk warnings recover on rotation (one alert latches open); two nodes cross into real `DiskPressure` eviction risk and a PVC hits 100% — tagged only SEV3. |
| [`deploy-storm`](datasets/noisebench/deploy-storm/) | hard | 29 | A dozen services deployed at once; almost all the churn self-heals. A few regressions don't. Over-suppressing kills you. |
| [`quiet-but-deadly`](datasets/noisebench/quiet-but-deadly/) | hard | 20 | SEV1-tagged flappers that must be suppressed; quiet SEV2/SEV3 slow-burns — including one that auto-resolved once before escalating — that must page. |
| [`slow-burn-saturation`](datasets/noisebench/slow-burn-saturation/) | hard | 20 | Plateau-under-limit (benign, deploy-explained) vs ratcheting-floor (deadly): both "rising ⇒ page" and "flapping ⇒ suppress" have counterexamples. |
| [`sev1-misconfigured-rule`](datasets/noisebench/sev1-misconfigured-rule/) | hard | 24 | A misconfigured monitor rule tags 12 benign blips SEV1; severity, rule-source, fired-count and pattern all mislead — only the metric trajectory disambiguates. |
| [`ci-e2e-test-noise`](datasets/noisebench/ci-e2e-test-noise/) | hard | 28 | CI / e2e test failures wired into PagerDuty — test-env noise that shouldn't page prod — vs real prod regressions, including a canary-fleet look-alike. |
| [`ai-platform-alert-noise`](datasets/noisebench/ai-platform-alert-noise/) | hard | 22 | `LLM 24 Hour Token Usage` warns + `Spending Cap` budget alerts — cost noise, not outages — vs real AI-runtime incidents. |
| [`queue-backlog-vs-blip`](datasets/noisebench/queue-backlog-vs-blip/) | hard | 26 | Queue blips that drain on their own vs sustained backlogs, a DLQ fill, and a consumer whose queue floor ratchets up while presenting as a flapper. |
| [`mixed-triage-heavy`](datasets/noisebench/mixed-triage-heavy/) | hard | 32 | The kitchen sink: every trap class in one 32-page batch; precision and recall stressed simultaneously. |

## Leaderboard

Frozen run (v2): **17 scenarios x 22 models x 3 attempts = 1122 trials**, Harbor `terminus-2` over OpenRouter, 2026-07-06/07/10/23/24, zero agent exceptions. Models are ranked on **mean graded reward** (0 on a cardinal `must_page` failure, otherwise F1; ± 95% CI over the 51 trials — see [dataset README → How scoring works](datasets/noisebench/README.md#how-scoring-works)), with the binary pass rate and per-tier pass rates alongside. Full per-trial results (outcome, graded reward, cost, tokens, timing per model) + per-model/per-task rollups are committed under [`benchmark-results/`](benchmark-results/).

> v1 → v2: the original 2026-06-30/07-02 run used a 600s agent timeout, which invalidated
> claude-opus-4.8's row (13 of its 20 failures were `AgentTimeoutError` on a slow
> OpenRouter day; re-tested it scores 82%, not 61%). v2 raises the agent timeout to 1800s
> for every model, runs on the revised scenario data (severity-inversion / latched-alert
> traps in `disk-pressure-flapper-storm` and `node-event-noise`), and captures per-trial
> graded rewards. Aside from opus (+22) and haiku (−14, mostly the severity traps),
> models moved within run-to-run variance (±4 points).

| Model | Mean graded reward (95% CI) | Pass rate | easy | medium | hard |
|---|---|---|---|---|---|
| claude-fable-5 | **0.917 ± 0.074** | 92% | 100% | 100% | 83% |
| claude-sonnet-4.6 | **0.909 ± 0.074** | 92% | 100% | 100% | 83% |
| fugu-ultra | **0.882 ± 0.089** | 88% | 100% | 100% | 75% |
| gpt-5.6-sol | **0.882 ± 0.089** | 88% | 100% | 100% | 75% |
| gpt-5.5 | **0.881 ± 0.089** | 88% | 100% | 100% | 75% |
| kimi-k3 | **0.875 ± 0.089** | 88% | 100% | 100% | 75% |
| glm-5.2 | **0.874 ± 0.089** | 88% | 100% | 100% | 75% |
| grok-4.5 | **0.863 ± 0.095** | 86% | 100% | 100% | 71% |
| gpt-5.4 | **0.829 ± 0.100** | 84% | 100% | 96% | 71% |
| claude-opus-4.8 | **0.824 ± 0.106** | 82% | 100% | 100% | 62% |
| deepseek-v4-flash | **0.820 ± 0.105** | 82% | 100% | 100% | 62% |
| kimi-k2.5 | **0.761 ± 0.113** | 75% | 100% | 96% | 50% |
| gpt-5.4-mini | **0.756 ± 0.111** | 76% | 100% | 92% | 58% |
| gemini-3.5-flash | **0.745 ± 0.121** | 75% | 100% | 100% | 46% |
| kimi-k2-thinking | **0.719 ± 0.113** | 67% | 67% | 92% | 42% |
| gemini-3.1-pro-preview | **0.704 ± 0.126** | 71% | 100% | 100% | 38% |
| gemini-3.1-flash-lite | **0.668 ± 0.121** | 63% | 100% | 92% | 29% |
| claude-haiku-4.5 | **0.543 ± 0.121** | 47% | 100% | 62% | 25% |
| gpt-oss-120b | **0.539 ± 0.132** | 53% | 100% | 88% | 12% |
| qwen3-235b-a22b-2507 | **0.426 ± 0.132** | 41% | 100% | 67% | 8% |
| qwen3-32b | **0.194 ± 0.103** | 20% | 67% | 29% | 4% |
| gpt-oss-20b | **0.167 ± 0.095** | 16% | 67% | 12% | 12% |

## Baselines: can a script solve it?

A benchmark is only credible if it can't be gamed by a trivial policy. Five deterministic,
non-LLM baselines run through the exact same scoring rules as the grader
([`scripts/run_baselines.py`](scripts/run_baselines.py); per-scenario results in
[`benchmark-results/noisebench/baselines.json`](benchmark-results/noisebench/baselines.json)):

| Baseline | Policy | Pass rate | easy | medium | hard | Mean F1 | Mean graded reward |
|---|---|---|---|---|---|---|---|
| `page-all` | page everything | 0/17 | 0/1 | 0/8 | 0/8 | 0.28 | 0.28 |
| `suppress-all` | suppress everything | 0/17 | 0/1 | 0/8 | 0/8 | 0.00 | 0.00 |
| `severity-gate` | page iff SEV1/SEV2 | 0/17 | 0/1 | 0/8 | 0/8 | 0.53 | 0.28 |
| `never-resolved` | page iff it never auto-resolved | 1/17 | 0/1 | 1/8 | 0/8 | 0.59 | 0.32 |
| `scripted-triage` | ~20-line SRE heuristic: flap/transient filters, open-incident dedup, pattern-delta gate, one page per root pattern | 9/17 | 1/1 | 8/8 | 0/8 | 0.90 | 0.52 |

*Mean graded reward = the per-trial graded score (0 on a cardinal `must_page` failure,
otherwise F1) averaged over scenarios — the same metric models are ranked on. The
scripted heuristic's respectable mean F1 collapses to 0.52 graded because it suppresses
a must-page incident in **all 8 hard scenarios**: exactly the real-incident-disguised-
as-noise traps that require reading the metric trajectory.*

Two takeaways:

- **The difficulty tiers are real.** A plausible scripted heuristic solves the easy and
  medium tiers but **fails all 8 hard scenarios** — the hard tier's feature-misleading traps
  (real incidents disguised as flappers, benign rises disguised as slow-burns) can only be
  resolved by reading the full metric trajectory in context, which is exactly the reasoning
  the benchmark wants to measure. Compare the model leaderboard above: the hard column is
  where models separate.
- **Severity never predicts the answer.** Paging by severity alone passes zero scenarios —
  `disk-pressure-flapper-storm` and `node-event-noise` (previously solvable that way) now
  carry explicit severity inversions: a SEV1-tagged flapper next to a real incident wearing
  the monitor's default SEV3. One known soft spot remains: `never-resolved` passes
  `warning-spike-transients` (flagged as a CI warning, slated for a latched-alert trap in a
  future data revision).

CI ([`oracle-check`](.github/workflows/oracle-check.yml)) enforces on every push: every
scenario's oracle (`solution/solve.sh`) scores exactly 1.0 against its own grader, the data is
internally consistent (labels ↔ pages, `must_page` ⊆ page-labels, pattern/deploy references
resolve), and no degenerate baseline passes any scenario.

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
turning a firehose of alerts into the handful that deserve a human. NoiseBench is our attempt to
measure that reasoning honestly and in the open — for any model, with no product in the loop.
EdgeDelta isn't on the leaderboard; the benchmark is neutral.

## License

Apache-2.0. See [LICENSE](LICENSE).
