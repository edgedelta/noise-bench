#!/usr/bin/env python3
"""NoiseBench oracle + data-integrity check (no Docker needed).

For every scenario under datasets/noisebench/ this verifies:

  1. STRUCTURE   — ground_truth labels cover exactly the ids in pages.json;
                   must_page ids are labeled "page"; thresholds present;
                   related_pattern / recent_deploy ids resolve.
  2. SOLVE.SH    — replaying solution/solve.sh (with /workdir redirected to a
                   temp dir) emits a valid triage.json; if a committed
                   solution/triage.json exists it must match (no drift).
  3. ORACLE      — the emitted decisions cover every page exactly once and
                   match ground-truth labels exactly (i.e. F1 = 1.0).
  4. GRADER      — the scenario's real grader (tests/test_outputs.py) passes
                   all three checks (cardinal, miss_budget, F1) on the oracle.

Exit code 0 = every scenario clean. Run by CI on every push/PR.
"""

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATASET = REPO / "datasets" / "noisebench"


def fail(scenario, msg):
    print(f"  FAIL [{scenario}] {msg}")
    return 1


def check_structure(name, d):
    errors = 0
    wd = d / "environment" / "workdir"
    pages = json.loads((wd / "pages.json").read_text())
    gt = json.loads((d / "tests" / "ground_truth.json").read_text())

    page_ids = {p["id"] for p in pages}
    label_ids = set(gt["labels"])
    if page_ids != label_ids:
        errors += fail(name, f"labels/pages id mismatch: only in pages {page_ids - label_ids}, "
                             f"only in labels {label_ids - page_ids}")
    if len(pages) != len(page_ids):
        errors += fail(name, "duplicate page ids in pages.json")

    for pid in gt.get("must_page", []):
        if gt["labels"].get(pid) != "page":
            errors += fail(name, f"must_page id {pid} not labeled 'page'")
    if not gt.get("must_page"):
        errors += fail(name, "must_page is empty")
    if not (0 < gt.get("f1_threshold", 0) <= 1):
        errors += fail(name, f"bad f1_threshold {gt.get('f1_threshold')}")
    if gt.get("positive_class", "page") != "page":
        errors += fail(name, f"unexpected positive_class {gt.get('positive_class')}")

    patterns = {q["pattern_id"] for q in json.loads((wd / "patterns.json").read_text())}
    deploys = {v["version"] for v in json.loads((wd / "deploys.json").read_text())}
    for p in pages:
        if p.get("related_pattern") and p["related_pattern"] not in patterns:
            errors += fail(name, f"{p['id']}: related_pattern {p['related_pattern']!r} "
                                 f"not in patterns.json")
        if p.get("recent_deploy") and p["recent_deploy"] not in deploys:
            errors += fail(name, f"{p['id']}: recent_deploy {p['recent_deploy']!r} "
                                 f"not in deploys.json")
    return errors, gt, page_ids


def decisions_of(triage):
    return {d["page_id"]: d["decision"] for d in triage["decisions"]}


def replay_solve_sh(name, d):
    """Replay solve.sh into a temp dir. Returns (errors, emitted triage dict).
    If a committed solution/triage.json exists, it must match the emitted one."""
    solve = d / "solution" / "solve.sh"
    with tempfile.TemporaryDirectory() as tmp:
        script = solve.read_text().replace("/workdir", tmp)
        r = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        if r.returncode != 0:
            return fail(name, f"solve.sh failed: {r.stderr.strip()[:200]}"), None
        emitted_path = Path(tmp) / "triage.json"
        if not emitted_path.exists():
            return fail(name, "solve.sh did not write triage.json"), None
        emitted = json.loads(emitted_path.read_text())
    committed_path = d / "solution" / "triage.json"
    if committed_path.exists():
        committed = json.loads(committed_path.read_text())
        if decisions_of(emitted) != decisions_of(committed):
            return fail(name, "solve.sh output drifted from committed "
                              "solution/triage.json"), emitted
    return 0, emitted


def check_oracle_matches_labels(name, triage, gt, page_ids):
    errors = 0
    dec = decisions_of(triage)
    if set(dec) != page_ids:
        errors += fail(name, f"oracle decision ids != pages.json ids "
                             f"(missing {page_ids - set(dec)}, extra {set(dec) - page_ids})")
    if len(triage["decisions"]) != len(dec):
        errors += fail(name, "duplicate page_id in oracle decisions")
    diff = {pid: (dec.get(pid), gt["labels"][pid])
            for pid in gt["labels"] if dec.get(pid) != gt["labels"][pid]}
    if diff:
        errors += fail(name, f"oracle decisions differ from ground truth (not F1=1.0): {diff}")
    return errors


def check_grader_passes_oracle(name, d, triage):
    """Run the scenario's actual grader against the oracle answer (silently;
    grader output is shown only on failure)."""
    errors = 0
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "triage.json").write_text(json.dumps(triage))
        spec = importlib.util.spec_from_file_location(
            f"grader_{name.replace('-', '_')}", d / "tests" / "test_outputs.py")
        grader = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(grader)
        grader.TRIAGE_PATH = str(Path(tmp) / "triage.json")
        for test in (grader.test_cardinal_no_real_sev_suppressed,
                     grader.test_miss_budget,
                     grader.test_f1_threshold):
            buf = io.StringIO()
            try:
                with contextlib.redirect_stdout(buf):
                    test()
            except AssertionError as e:
                print(buf.getvalue(), end="")
                errors += fail(name, f"grader rejected the oracle: {e}")
    return errors


def main():
    scenarios = sorted(p for p in DATASET.iterdir()
                       if (p / "tests" / "ground_truth.json").exists())
    if not scenarios:
        print(f"no scenarios found under {DATASET}")
        sys.exit(1)

    total_errors = 0
    for d in scenarios:
        name = d.name
        errs, gt, page_ids = check_structure(name, d)
        solve_errs, triage = replay_solve_sh(name, d)
        errs += solve_errs
        if triage is not None:
            errs += check_oracle_matches_labels(name, triage, gt, page_ids)
            errs += check_grader_passes_oracle(name, d, triage)
        status = "OK  " if errs == 0 else "FAIL"
        print(f"{status} {name}  (pages={len(page_ids)}, must_page={len(gt['must_page'])}, "
              f"f1>={gt['f1_threshold']}, miss_budget={gt.get('miss_budget', 0)})")
        total_errors += errs

    print(f"\n{len(scenarios)} scenarios checked, "
          f"{'all clean' if total_errors == 0 else f'{total_errors} error(s)'}")
    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
