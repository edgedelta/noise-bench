# PageBench — ci-e2e-test-noise

24 alerts fired across a CI-heavy morning. Most are CircleCI / Playwright e2e test-failure alerts (`hourly_playwright_sev0_*`) wired into PagerDuty as incidents — test-environment noise and flaky retries that self-resolve and should never page production on-call. The trap: ONE e2e failure is corroborated by real production error signal and reflects a genuine customer-facing web-app regression. Decide who to wake up.

You are the on-call triage engineer. A batch of **24 fired alerts (pages)**
is waiting in `/workdir/pages.json`. For each one you must decide: **page** a human, or
**suppress** it as noise. Waking someone for noise burns trust and sleep; missing a real
incident is far worse.

This scenario is a reconstruction of a representative production incident class; all service,
host, monitor, and identifier values are fictional stand-ins.

## Data available in `/workdir/`

| File | What it is |
|------|------------|
| `pages.json` | The batch of fired alerts. Each object has: `id`, `service`, `monitor`, `metric`, `severity`, `fired_at`, `value`, `threshold`, `fired_count_last_1h` (how often this same alert fired in the past hour), `auto_resolved_after_s` (seconds until it self-cleared, or `null` if it never did), `related_pattern` (id into `patterns.json`), `recent_deploy` (version id into `deploys.json`, or `null`). |
| `metrics.csv` | `timestamp,service,metric,value` — baseline and incident-window samples for the services that matter. |
| `patterns.json` | Clustered log signatures with `count`, `delta_vs_baseline_pct`, `sentiment`. The truth-teller for whether something is actually breaking. |
| `deploys.json` | Deploy events (`timestamp`, `service`, `commit_sha`, `version`). Some are innocent decoys near incident onset. |
| `incidents_open.json` | Incidents a human is ALREADY working. A page that duplicates one of these should be suppressed. |

You have shell tools (`jq`, `grep`, `cat`, …) to query the data. EdgeDelta's query
language is **CQL** (field equality like `severity:"SEV1"`, boolean `AND`/`OR`/negation,
numeric comparisons like `@value > 400`; no regex, no mid-string wildcards) — the data
here is plain JSON/CSV, so use `jq`/`grep` to reason as if running CQL filters.

## How to think about it

- **Flapping**: a high `fired_count_last_1h` that oscillates around its threshold and
  self-clears fast is a chronic flapper, not an incident. The `[ignore]`-prefixed monitors
  ("[ignore] Default Log Threshold Monitor") fire constantly across services and are noise
  by design.
- **Transient**: `auto_resolved_after_s` is small (tens of seconds) and the metric
  returned to baseline → it already healed. Don't wake anyone.
- **Operational meta-noise**: config-level and cost/budget warnings, normal Karpenter/PDB
  operational events ("Pdb prevents pod evictions", "SpotToSpotConsolidation disabled",
  "Unconsolidatable", "store validated"), and CI/test-failure alerts firing as incidents
  are usually NOT a production outage.
- **Correlation / dedup**: multiple pages sharing the same `related_pattern` and a tight
  onset window are usually ONE incident — page the root, suppress the symptoms. A page
  matching an entry in `incidents_open.json` is already owned.
- **The real one**: a sustained, non-self-resolving signal with a surging negative log
  pattern and genuine production impact is the page that must wake a human — even when it
  is buried under look-alike noise.

## Rules

1. Decide each page independently into exactly one of: `page` (wake a human now — a real, actionable incident) or `suppress` (noise that should not page anyone).
2. Be specific in `reason`: cite the evidence (auto-resolve time, fired_count, pattern delta, deploy correlation, open-incident dedup, monitor name) that drove the call.
3. Do NOT speculate. If a page is genuinely ambiguous, fall back to the SAFE default: when a real, high-severity incident might be at stake, `page` it. Suppress only when the evidence clearly says noise.
4. A real incident often fires SEVERAL correlated pages (root + downstream symptoms). Collapse correlated pages that share a root pattern and onset window into ONE page (the root); suppress the rest as duplicates.
5. If a page duplicates an incident already in `incidents_open.json`, suppress it — a human is already engaged.

## Output — write these two files

1. `/workdir/triage.json` — your machine-checkable answer, exactly this schema:

```json
{
  "decisions": [
    { "page_id": "<id>", "decision": "page" | "suppress", "reason": "<short>" }
  ]
}
```

   Include **one decision object per page** in `pages.json`. `decision` must be exactly
   `"page"` or `"suppress"`.

2. `/workdir/reasoning.md` — free-form notes: how you grouped correlated pages, what you
   treated as noise and why, and which single incident (if any) you are confident is real.

## How you are scored

- Positive class = `page`. We compute precision / recall / **F1** against ground-truth
  labels. You must reach **F1 ≥ 0.78**.
- **Cardinal rule**: there is at least one real, high-severity incident that MUST be
  paged. Suppressing it scores **zero**, no matter how good your F1 is. When in doubt
  about a real incident, page it.
- Over-paging is penalized: every piece of noise you page hurts precision (and your
  team's trust). The bar rewards waking humans for real incidents and *only* real
  incidents.
