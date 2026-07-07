#!/usr/bin/env python3
"""Run deterministic (non-LLM) baseline policies over every NoiseBench scenario.

Why: a benchmark is only credible if it cannot be solved by a trivial script.
This runs a ladder of scripted policies — from degenerate (page-all,
suppress-all) to a plausible ~20-line SRE heuristic — through the exact same
scoring rules as the real grader (cardinal must_page, miss_budget, F1
threshold), and reports pass/fail per scenario.

Usage:
  python3 scripts/run_baselines.py            # print table, write baselines.json
  python3 scripts/run_baselines.py --check    # CI mode: exit 1 if a DEGENERATE
                                              # baseline passes any scenario
"""

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATASET = REPO / "datasets" / "noisebench"
OUT_PATH = REPO / "benchmark-results" / "noisebench" / "baselines.json"

# Baselines that must NEVER pass a scenario. If one does, the scenario is
# trivially gameable and CI fails hard.
DEGENERATE = ("page-all", "suppress-all")
# Cheap single-field heuristics: a pass is a data-quality smell (the scenario is
# solvable without reading metric trends), surfaced as a CI warning.
CHEAP = ("severity-gate", "never-resolved")


# --- baseline policies --------------------------------------------------------
# Each policy: (pages, workdir_data) -> {page_id: "page" | "suppress"}

def page_all(pages, _):
    return {p["id"]: "page" for p in pages}


def suppress_all(pages, _):
    return {p["id"]: "suppress" for p in pages}


def severity_gate(pages, _):
    """Trust the severity tag: page SEV1/SEV2, suppress the rest."""
    return {p["id"]: "page" if p["severity"] in ("SEV1", "SEV2") else "suppress"
            for p in pages}


def never_resolved(pages, _):
    """Page anything that never auto-resolved."""
    return {p["id"]: "page" if p["auto_resolved_after_s"] is None else "suppress"
            for p in pages}


def scripted_triage(pages, data):
    """A plausible ~20-line on-call script: flap/transient filters, open-incident
    dedup, pattern-delta gate, and root-only dedup per log pattern."""
    patterns = {q["pattern_id"]: q for q in data["patterns"]}
    open_patterns = {inc.get("related_pattern") for inc in data["incidents_open"]}
    decisions = {}
    candidates = []
    for p in pages:
        pat = patterns.get(p.get("related_pattern"), {})
        if p.get("related_pattern") in open_patterns:
            decisions[p["id"]] = "suppress"          # a human already owns it
        elif p["auto_resolved_after_s"] is not None:
            decisions[p["id"]] = "suppress"          # it self-healed
        elif p["fired_count_last_1h"] >= 5:
            decisions[p["id"]] = "suppress"          # chronic flapper
        elif pat.get("sentiment") == "negative" or pat.get("delta_vs_baseline_pct", 0) >= 50:
            candidates.append(p)                     # looks genuinely broken
        else:
            decisions[p["id"]] = "suppress"          # quiet pattern -> noise
    roots = {}                                       # page one root per pattern
    for p in sorted(candidates, key=lambda x: x["fired_at"]):
        key = p.get("related_pattern") or p["id"]
        decisions[p["id"]] = "page" if key not in roots else "suppress"
        roots.setdefault(key, p["id"])
    return decisions


BASELINES = {
    "page-all": page_all,
    "suppress-all": suppress_all,
    "severity-gate": severity_gate,
    "never-resolved": never_resolved,
    "scripted-triage": scripted_triage,
}


# --- scoring (identical rules to tests/test_outputs.py) ------------------------

def score(pred, gt):
    truth = gt["labels"]
    tp = fp = fn = 0
    false_suppress, false_page = [], []
    for pid, t in truth.items():
        p = pred.get(pid, "suppress")
        if t == "page" and p == "page":
            tp += 1
        elif t == "page":
            fn += 1
            false_suppress.append(pid)
        elif p == "page":
            fp += 1
            false_page.append(pid)
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0

    must_page = gt.get("must_page", [])
    missed_must = [pid for pid in must_page if pred.get(pid) != "page"]
    non_must_missed = [pid for pid in false_suppress if pid not in must_page]
    miss_budget = gt.get("miss_budget", 0)

    passed = (not missed_must
              and len(non_must_missed) <= miss_budget
              and f1 >= gt["f1_threshold"])
    return {
        "passed": passed,
        "precision": round(precision, 3),
        "recall": round(recall, 3),
        "f1": round(f1, 3),
        # same graded reward the model grader emits: 0 on cardinal fail, else F1
        "graded_reward": 0.0 if missed_must else round(f1, 3),
        "cardinal_fail": bool(missed_must),
        "missed_must": missed_must,
        "false_page": false_page,
        "false_suppress": false_suppress,
    }


# --- driver --------------------------------------------------------------------

def load_scenario(d):
    wd = d / "environment" / "workdir"
    difficulty = "?"
    for line in (d / "task.toml").read_text().splitlines():
        if line.strip().startswith("difficulty"):
            difficulty = line.split("=")[1].strip().strip('"')
            break
    return {
        "pages": json.loads((wd / "pages.json").read_text()),
        "patterns": json.loads((wd / "patterns.json").read_text()),
        "incidents_open": json.loads((wd / "incidents_open.json").read_text()),
        "gt": json.loads((d / "tests" / "ground_truth.json").read_text()),
        "difficulty": difficulty,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="CI mode: fail if a degenerate baseline passes any scenario")
    args = ap.parse_args()

    scenarios = sorted(p for p in DATASET.iterdir()
                       if (p / "tests" / "ground_truth.json").exists())
    results = {name: {} for name in BASELINES}
    tiers = {}
    for d in scenarios:
        data = load_scenario(d)
        tiers[d.name] = data["difficulty"]
        for name, policy in BASELINES.items():
            pred = policy(data["pages"], data)
            r = score(pred, data["gt"])
            r["difficulty"] = data["difficulty"]
            results[name][d.name] = r

    width = max(len(d.name) for d in scenarios)
    header = f"{'scenario':<{width}}  {'tier':<6}  " + "  ".join(f"{n:>15}" for n in BASELINES)
    print(header)
    print("-" * len(header))
    for d in scenarios:
        cells = []
        for name in BASELINES:
            r = results[name][d.name]
            mark = "PASS" if r["passed"] else "fail"
            cells.append(f"{mark} f1={r['f1']:.2f}"[:15].rjust(15))
        print(f"{d.name:<{width}}  {tiers[d.name]:<6}  " + "  ".join(cells))

    print()
    summary = {}
    tier_names = sorted(set(tiers.values()))
    for name in BASELINES:
        rs = results[name]
        passed = sum(r["passed"] for r in rs.values())
        mean_f1 = sum(r["f1"] for r in rs.values()) / len(scenarios)
        mean_graded = sum(r["graded_reward"] for r in rs.values()) / len(scenarios)
        by_tier = {t: f"{sum(r['passed'] for s, r in rs.items() if tiers[s] == t)}"
                      f"/{sum(1 for s in rs if tiers[s] == t)}"
                   for t in tier_names}
        summary[name] = {"passed": passed, "total": len(scenarios),
                         "pass_rate_pct": round(100 * passed / len(scenarios), 1),
                         "mean_f1": round(mean_f1, 3),
                         "mean_graded_reward": round(mean_graded, 3),
                         "by_tier": by_tier}
        tier_str = "  ".join(f"{t} {by_tier[t]}" for t in tier_names)
        print(f"{name:>15}: {passed}/{len(scenarios)} passed, mean F1 {mean_f1:.3f}, "
              f"mean graded {mean_graded:.3f}  ({tier_str})")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(
        {"summary": summary, "by_scenario": results}, indent=2) + "\n")
    print(f"\nwrote {OUT_PATH.relative_to(REPO)}")

    if args.check:
        warns = [(n, s) for n in CHEAP
                 for s, r in results[n].items() if r["passed"]]
        for n, s in warns:
            print(f"WARNING: cheap heuristic '{n}' passes {s} — "
                  f"the scenario is solvable without reading metric trends.")
        leaks = [(n, s) for n in DEGENERATE
                 for s, r in results[n].items() if r["passed"]]
        if leaks:
            print("\nCI FAIL: degenerate baseline passed a scenario (trivially gameable):")
            for n, s in leaks:
                print(f"  {n} passed {s}")
            sys.exit(1)
        print("CI OK: no degenerate baseline passes any scenario.")


if __name__ == "__main__":
    main()
