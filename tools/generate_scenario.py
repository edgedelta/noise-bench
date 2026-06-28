#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# ///
"""Generate a new NoiseBench scenario skeleton.

WHY THIS EXISTS
---------------
The shipped scenarios (noisy-night-shift, deploy-storm, quiet-but-deadly) were
produced by the fault-injection pipeline described below, then hand-tuned for
distractor realism. This tool documents that pipeline and emits a *functional*
synthetic scenario you can grow from.

THE FAULT-INJECTION PIPELINE (how the real scenarios are made)
--------------------------------------------------------------
1. Run a microservices demo app (e.g. GoogleCloudPlatform/microservices-demo or
   the EdgeDelta load-gen harness) under steady synthetic load.
2. Pick ONE real fault tied to a specific git commit (the culprit): a connection
   leak, an N+1 query, a bad pool client, a slow upstream. Deploy it.
3. Let the fault propagate. Capture the alert pages that fire, the metrics, the
   clustered log patterns, the deploy log, and any already-open incidents.
4. Freeze a window of telemetry (a few minutes to a few hours) into small files.
5. Inject DISTRACTORS so the model can't win by pattern-matching:
     - chronic flappers (high fired_count, fast auto-resolve),
     - sub-minute transients that self-heal,
     - downstream symptoms of the real incident (to test correlation/dedup),
     - an innocent deploy near onset (to punish "blame the latest deploy"),
     - a duplicate of an already-open incident (to test dedup vs incidents_open).
6. Emit ground_truth.json: per-page page/suppress labels + the must_page list
   (the real incident that scoring will NEVER let you suppress).

In v1 the root-cause label space is GIT COMMITS (code changes). Feature-flag
changes appear only as decoys; they are never the labelled culprit.

WHAT THIS STUB DOES
-------------------
Emits a complete, runnable scenario directory (all 6 task files + data) with one
injected real incident and a configurable number of noise pages. It is enough to
`harbor run`; replace the synthetic data with a captured window for a real task.

Usage:
    uv run tools/generate_scenario.py my-new-scenario --noise 15 --difficulty medium
"""
from __future__ import annotations

import argparse
import json
import os
import random
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DS = REPO / "datasets" / "noisebench"

NOISE_KINDS = [
    # (metric, related_pattern, threshold, value_factor, auto_resolve_s, fired_count)
    ("cpu_pct", "pat-gc-pause", 90.0, 1.02, 35, 3),
    ("disk_usage_pct", "pat-disk-rotate", 85.0, 1.01, 20, 14),
    ("p99_latency_ms", "pat-cold-cache", 800.0, 1.1, 28, 4),
    ("http_5xx_rate", "pat-rollout-503", 0.05, 1.2, 40, 2),
    ("memory_pct", "pat-gc-pause", 85.0, 1.02, 50, 2),
]
SERVICES = ["frontend", "cart", "checkout", "orders", "search",
            "recommendation", "notifications", "auth", "inventory"]


def build(name: str, noise: int, difficulty: str, seed: int):
    rng = random.Random(seed)
    D = "2026-07-01"
    pages, labels, rationale = [], {}, {}

    def add(pid, service, metric, fired_at, value, threshold, fc, ars,
            pattern, deploy, severity, label, reason):
        pages.append(dict(id=pid, service=service, metric=metric, severity=severity,
                          fired_at=fired_at, value=value, threshold=threshold,
                          fired_count_last_1h=fc, auto_resolved_after_s=ars,
                          related_pattern=pattern, recent_deploy=deploy))
        labels[pid] = label
        rationale[pid] = reason

    # One real, must-page incident (never auto-resolves, surging pattern, no deploy).
    add("R01", "api-gateway", "error_rate", f"{D}T12:00:00Z", 0.24, 0.05, 1, None,
        "pat-upstream-timeout", None, "SEV1", "page",
        "Real incident: error rate 24% >> 5% threshold, never auto-resolved, "
        "upstream-timeout pattern surging. Root culprit commit, no innocent deploy "
        "to blame. Must page.")

    # Noise pages.
    for i in range(noise):
        pid = f"N{i+1:02d}"
        metric, pattern, thr, vf, ars, fc = rng.choice(NOISE_KINDS)
        svc = rng.choice(SERVICES)
        minute = 5 + i * 2
        add(pid, svc, metric, f"{D}T11:{minute:02d}:00Z", round(thr * vf, 4),
            thr, fc, ars + rng.randint(-5, 8), pattern, None, "SEV4", "suppress",
            f"Noise: {metric} blip on {svc}, auto-resolved in ~{ars}s "
            f"({pattern}). Below page-worthy duration/impact.")

    metrics = [
        (f"{D}T11:50:00Z", "api-gateway", "error_rate", 0.03),
        (f"{D}T12:00:00Z", "api-gateway", "error_rate", 0.24),
        (f"{D}T12:10:00Z", "api-gateway", "error_rate", 0.31),
    ]
    patterns = [
        dict(pattern_id="pat-upstream-timeout",
             signature="api-gateway: upstream request timed out", count=900,
             delta_vs_baseline_pct=800, sentiment="negative", first_seen=f"{D}T12:00:00Z"),
        dict(pattern_id="pat-gc-pause", signature="GC pause exceeded soft limit",
             count=120, delta_vs_baseline_pct=4, sentiment="neutral", first_seen=f"{D}T11:00:00Z"),
        dict(pattern_id="pat-disk-rotate", signature="disk usage high; triggering log rotation",
             count=14, delta_vs_baseline_pct=0, sentiment="neutral", first_seen=f"{D}T11:00:00Z"),
        dict(pattern_id="pat-cold-cache", signature="cache miss storm after eviction",
             count=60, delta_vs_baseline_pct=5, sentiment="neutral", first_seen=f"{D}T11:00:00Z"),
        dict(pattern_id="pat-rollout-503", signature="upstream 503 during pod rollout",
             count=10, delta_vs_baseline_pct=0, sentiment="neutral", first_seen=f"{D}T11:00:00Z"),
    ]
    # innocent decoy deploy near onset
    deploys = [dict(timestamp=f"{D}T11:58:00Z", service="frontend",
                    commit_sha="dec0y01", version="fe-2026.07.01-a",
                    note="innocent: recovered, different service from culprit")]
    incidents = []

    gt = dict(scenario=name, f1_threshold=(0.78 if difficulty == "hard" else 0.80),
              miss_budget=0, positive_class="page", must_page=["R01"],
              labels=labels, rationale=rationale,
              notes="Synthetic skeleton from tools/generate_scenario.py. One real "
                    "must-page incident (R01) + noise. Replace with a captured window.")

    base = DS / name
    (base / "environment" / "workdir").mkdir(parents=True, exist_ok=True)
    (base / "solution").mkdir(parents=True, exist_ok=True)
    (base / "tests").mkdir(parents=True, exist_ok=True)

    def wj(p, o):
        p.write_text(json.dumps(o, indent=2) + "\n")

    wd = base / "environment" / "workdir"
    wj(wd / "pages.json", pages)
    (wd / "metrics.csv").write_text(
        "timestamp,service,metric,value\n" +
        "".join(",".join(str(x) for x in r) + "\n" for r in metrics))
    wj(wd / "patterns.json", patterns)
    wj(wd / "deploys.json", deploys)
    wj(wd / "incidents_open.json", incidents)
    wj(base / "tests" / "ground_truth.json", gt)

    decisions = [dict(page_id=p["id"], decision=labels[p["id"]],
                      reason=rationale[p["id"]]) for p in pages]
    wj(base / "solution" / "triage.json", dict(decisions=decisions))

    print(f"Generated scenario skeleton at {base}")
    print("Next: copy task.toml / instruction.md / environment/Dockerfile / "
          "tests/test.sh / tests/test_outputs.py / solution/solve.sh from an "
          "existing scenario, adjust difficulty, and replace the synthetic data "
          "with a captured telemetry window.")


def main():
    ap = argparse.ArgumentParser(description="Generate a NoiseBench scenario skeleton.")
    ap.add_argument("name", help="scenario directory name, e.g. weekend-cron-storm")
    ap.add_argument("--noise", type=int, default=15, help="number of noise pages")
    ap.add_argument("--difficulty", choices=["easy", "medium", "hard"], default="medium")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    build(args.name, args.noise, args.difficulty, args.seed)


if __name__ == "__main__":
    main()
