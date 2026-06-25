#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""Summarise Harbor result.json files for PageBench into a markdown table.

Harbor writes one `result.json` per trial under `jobs/<run>/<trial>/result.json`.
Each has a `task_name`, the agent `config.agent.model_name`, and a
`verifier_result.rewards.reward` (1.0 = passed, 0.0 = failed).

Usage:
    uv run scripts/process_results.py jobs/2026-06-25__10-00-00 [more_job_dirs ...]

Prints:
    * a per-model pass-rate table (one row per model, columns = scenarios + overall)
    * a per-difficulty breakdown

This is intentionally small and dependency-free so it runs anywhere.
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

# scenario -> difficulty (keep in sync with each task.toml)
DIFFICULTY = {
    "noisy-night-shift": "medium",
    "deploy-storm": "hard",
    "quiet-but-deadly": "medium",
}
SCENARIOS = list(DIFFICULTY.keys())


def reward_of(result: dict) -> float:
    vr = result.get("verifier_result") or {}
    rewards = vr.get("rewards") or {}
    return float(rewards.get("reward", 0.0))


def model_of(result: dict) -> str:
    name = result.get("config", {}).get("agent", {}).get("model_name", "unknown")
    return name.split("/")[-1]


def collect(job_dirs: list[Path]):
    # (model, scenario) -> [rewards]
    cells: dict[tuple[str, str], list[float]] = defaultdict(list)
    files: list[Path] = []
    for d in job_dirs:
        files.extend(sorted(d.glob("*/result.json")))
    if not files:
        print("No result.json files found under the given job dir(s).", file=sys.stderr)
        sys.exit(1)
    for f in files:
        try:
            r = json.loads(f.read_text())
        except Exception as e:
            print(f"  skip {f}: {e}", file=sys.stderr)
            continue
        cells[(model_of(r), r.get("task_name", "?"))].append(reward_of(r))
    return cells, len(files)


def pct(rewards: list[float]) -> str:
    if not rewards:
        return "—"
    return f"{100 * sum(1 for x in rewards if x >= 1.0) / len(rewards):.0f}%"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    job_dirs = [Path(p) for p in sys.argv[1:]]
    cells, n = collect(job_dirs)
    models = sorted({m for (m, _) in cells})

    print(f"\nPageBench results — {n} trials across {len(models)} model(s)\n")

    # Per-model x scenario table
    header = "| Model | " + " | ".join(SCENARIOS) + " | Overall |"
    sep = "|" + "---|" * (len(SCENARIOS) + 2)
    print(header)
    print(sep)
    for m in models:
        row = [m]
        all_rewards: list[float] = []
        for s in SCENARIOS:
            rw = cells.get((m, s), [])
            all_rewards += rw
            row.append(pct(rw))
        row.append(pct(all_rewards))
        print("| " + " | ".join(row) + " |")

    # Per-difficulty breakdown
    print("\n### By difficulty\n")
    print("| Model | medium | hard |")
    print("|---|---|---|")
    for m in models:
        by_diff: dict[str, list[float]] = defaultdict(list)
        for s in SCENARIOS:
            by_diff[DIFFICULTY[s]] += cells.get((m, s), [])
        print(f"| {m} | {pct(by_diff['medium'])} | {pct(by_diff['hard'])} |")
    print()


if __name__ == "__main__":
    main()
