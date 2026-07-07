#!/usr/bin/env python3
"""Compare a fresh Harbor run against the committed benchmark results.

BEFORE = benchmark-results/noisebench/results.json (the frozen leaderboard run)
AFTER  = one or more Harbor job dirs (jobs/<run>/<trial>/result.json)

Only models present in the AFTER run are compared. Prints per-model pass rates
side by side, then every (model, scenario) whose pass count changed.

Usage: python3 scripts/compare_runs.py jobs/<run> [more_job_dirs ...]
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BEFORE_PATH = REPO / "benchmark-results" / "noisebench" / "results.json"


def short(model):
    return model.split("/")[-1]


def load_before():
    """{(model, task): [pass_bool, ...]}"""
    runs = defaultdict(list)
    for r in json.loads(BEFORE_PATH.read_text()):
        runs[(short(r["ModelName"]), r["TaskName"])].append(bool(r["Passed"]))
    return runs


def load_after(job_dirs):
    runs = defaultdict(list)
    for jd in job_dirs:
        for f in sorted(Path(jd).glob("*__*/result.json")):
            try:
                d = json.loads(f.read_text())
            except json.JSONDecodeError:
                continue
            model = (d.get("config", {}).get("agent", {}) or {}).get("model_name") or "unknown"
            task = d.get("task_name") or f.parent.name.split("__")[0]
            reward = ((d.get("verifier_result") or {}).get("rewards") or {}).get("reward")
            if reward is None:
                rt = f.parent / "verifier" / "reward.txt"
                reward = float(rt.read_text().strip() or 0) if rt.exists() else 0.0
            runs[(short(model), task)].append(float(reward) >= 1.0)
    return runs


def rate(runs, model, tasks=None):
    trials = [p for (m, t), ps in runs.items() if m == model
              and (tasks is None or t in tasks) for p in ps]
    return (100 * sum(trials) / len(trials), len(trials)) if trials else (0.0, 0)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    before, after = load_before(), load_after(sys.argv[1:])
    if not after:
        sys.exit("no result.json files found in the given job dir(s) — run still going?")

    models = sorted({m for m, _ in after})
    tasks = sorted({t for _, t in after})

    print(f"{'model':<28} {'before':>14} {'after':>14} {'delta':>7}")
    print("-" * 66)
    for m in models:
        b_pct, b_n = rate(before, m, set(tasks))
        a_pct, a_n = rate(after, m)
        print(f"{m:<28} {b_pct:>6.1f}% ({b_n:>3}) {a_pct:>6.1f}% ({a_n:>3}) "
              f"{a_pct - b_pct:>+6.1f}")

    print("\nPer-scenario flips (pass count out of attempts, before -> after):")
    any_flip = False
    for m in models:
        for t in tasks:
            b = before.get((m, t), [])
            a = after.get((m, t), [])
            if b and a and (sum(b) != sum(a) or len(b) != len(a)):
                any_flip = True
                print(f"  {m:<28} {t:<32} {sum(b)}/{len(b)} -> {sum(a)}/{len(a)}")
    if not any_flip:
        print("  none — identical pass counts per (model, scenario)")


if __name__ == "__main__":
    main()
