# PageBench — noisy-night-shift

It is the night shift. Over a ~3-hour window, 20 alerts fired across your fleet. Buried in the pile is a genuine cascading database failure; the rest is flapping disk alerts, transient CPU blips that already self-healed, a duplicate of an incident a human is already working, and a deploy that self-healed. Decide who to wake up.

You are the on-call triage engineer. A batch of **20 fired alerts (pages)**
is waiting in `/workdir/pages.json`. For each one you must decide: **page** a human, or
**suppress** it as noise. Waking someone for noise burns trust and sleep; missing a real
incident is far worse.

## Data available in `/workdir/`

| File | What it is |
|------|------------|
| `pages.json` | The batch of fired alerts. Each object has: `id`, `service`, `metric`, `severity`, `fired_at`, `value`, `threshold`, `fired_count_last_1h` (how often this same alert fired in the past hour), `auto_resolved_after_s` (seconds until it self-cleared, or `null` if it never did), `related_pattern` (id into `patterns.json`), `recent_deploy` (version id into `deploys.json`, or `null`). |
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
  self-clears fast is a chronic flapper, not an incident.
- **Transient**: `auto_resolved_after_s` is small (tens of seconds) and the metric
  returned to baseline → it already healed. Don't wake anyone.
- **Correlation / dedup**: multiple pages sharing the same `related_pattern` and a tight
  onset window are usually ONE incident — page the root, suppress the symptoms. A page
  matching an entry in `incidents_open.json` is already owned.
- **Deploy churn vs. regression**: a deploy-correlated blip that self-heals is expected;
  one that keeps climbing and never resolves is a regression.
- **The quiet ones**: a small but monotonically rising metric that never auto-resolves
  can be a real slow-burn incident even with no deploy to blame.

## Rules

1. Decide each page independently into exactly one of: `page` (wake a human now — a real, actionable incident) or `suppress` (noise that should not page anyone).
2. Be specific in `reason`: cite the evidence (auto-resolve time, fired_count, pattern delta, deploy correlation, open-incident dedup) that drove the call.
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
  labels. You must reach **F1 ≥ 0.80**.
- **Cardinal rule**: there is at least one real, high-severity incident that MUST be
  paged. Suppressing it scores **zero**, no matter how good your F1 is. When in doubt
  about a real incident, page it.
- Over-paging is penalized: every piece of noise you page hurts precision (and your
  team's trust). The bar rewards waking humans for real incidents and *only* real
  incidents.
