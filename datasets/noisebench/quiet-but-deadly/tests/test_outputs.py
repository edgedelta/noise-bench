#!/usr/bin/env python3
"""NoiseBench grader.

Loads the model's /workdir/triage.json and the embedded ground truth
(tests/ground_truth.json, injected only at verification time), computes a
confusion matrix with the POSITIVE class = "page", and enforces:

  1. CARDINAL RULE: every page id in must_page MUST be classified "page".
     Suppressing a must-page (real, high-severity) incident => reward 0,
     regardless of F1. This dominates everything.
  2. PRIMARY: F1 (positive class = page) >= f1_threshold.
  3. miss_budget: number of *non-must-page* real incidents that may be
     missed (suppressed) and still pass. Default 0.

Secondary metrics (precision / recall / F1 / false-suppress / false-page)
are printed for the writeup but do not gate the binary reward beyond the
rules above.

Besides the binary verdict, the grader emits a GRADED reward — 0.0 on a
cardinal (must_page) failure, otherwise F1 — as a `NOISEBENCH_METRICS {json}`
stdout line and, when running under Harbor, /logs/verifier/metrics.json.
The graded reward does not affect pass/fail (reward.txt stays binary); it
exists so leaderboards can rank on mean graded reward instead of coarse
pass counts.
"""

import json
import os
import sys

TRIAGE_PATH = "/workdir/triage.json"
GT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ground_truth.json")
METRICS_PATH = os.environ.get("NOISEBENCH_METRICS_PATH", "/logs/verifier/metrics.json")


def load_ground_truth():
    with open(GT_PATH) as f:
        return json.load(f)


def load_decisions():
    assert os.path.exists(TRIAGE_PATH), f"{TRIAGE_PATH} does not exist"
    with open(TRIAGE_PATH) as f:
        data = json.load(f)
    assert isinstance(data, dict), "triage.json must be a JSON object"
    assert "decisions" in data, "triage.json must have a 'decisions' key"
    decisions = data["decisions"]
    assert isinstance(decisions, list), "'decisions' must be a list"
    by_id = {}
    for d in decisions:
        assert "page_id" in d, f"decision missing page_id: {d}"
        assert "decision" in d, f"decision missing decision: {d}"
        assert d["decision"] in ("page", "suppress"), \
            f"decision must be 'page' or 'suppress', got {d['decision']!r}"
        by_id[d["page_id"]] = d["decision"]
    return by_id


def confusion(pred, truth):
    """Positive class = 'page'."""
    tp = fp = tn = fn = 0
    false_suppress = []  # truth=page, pred=suppress  (missed real incident)
    false_page = []      # truth=suppress, pred=page  (noise leaked through)
    for pid, t in truth.items():
        p = pred.get(pid, "suppress")  # missing prediction = safest? no: missing => suppress
        if t == "page" and p == "page":
            tp += 1
        elif t == "page" and p == "suppress":
            fn += 1
            false_suppress.append(pid)
        elif t == "suppress" and p == "page":
            fp += 1
            false_page.append(pid)
        else:
            tn += 1
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) else 0.0
    return dict(tp=tp, fp=fp, tn=tn, fn=fn, precision=precision, recall=recall,
                f1=f1, false_suppress=false_suppress, false_page=false_page)


def _evaluate():
    gt = load_ground_truth()
    truth = gt["labels"]
    pred = load_decisions()
    cm = confusion(pred, truth)

    print(f"\n=== NoiseBench grader: {gt['scenario']} ===")
    print(f"pages: {len(truth)}  (page={sum(1 for v in truth.values() if v=='page')}, "
          f"suppress={sum(1 for v in truth.values() if v=='suppress')})")
    print(f"precision={cm['precision']:.3f}  recall={cm['recall']:.3f}  f1={cm['f1']:.3f}  "
          f"(threshold {gt['f1_threshold']:.2f})")
    print(f"tp={cm['tp']} fp={cm['fp']} tn={cm['tn']} fn={cm['fn']}")
    print(f"false-suppress (missed real incidents): {cm['false_suppress'] or 'none'}")
    print(f"false-page (noise that leaked through): {cm['false_page'] or 'none'}")

    must_page = gt.get("must_page", [])
    missed_must = [pid for pid in must_page if pred.get(pid) != "page"]
    print(f"must_page={must_page}  missed_must={missed_must or 'none'}")

    miss_budget = gt.get("miss_budget", 0)
    non_must_missed = [pid for pid in cm["false_suppress"] if pid not in must_page]
    print(f"non-must real incidents missed: {len(non_must_missed)} "
          f"(budget {miss_budget})  {non_must_missed or ''}")
    _emit_metrics(gt, cm, missed_must, non_must_missed, miss_budget)
    return gt, cm, missed_must, non_must_missed, miss_budget


def _emit_metrics(gt, cm, missed_must, non_must_missed, miss_budget):
    """Graded reward: 0.0 on cardinal failure, else F1. Reporting only."""
    metrics = {
        "scenario": gt["scenario"],
        "precision": round(cm["precision"], 4),
        "recall": round(cm["recall"], 4),
        "f1": round(cm["f1"], 4),
        "f1_threshold": gt["f1_threshold"],
        "missed_must": missed_must,
        "non_must_missed": non_must_missed,
        "miss_budget": miss_budget,
        "passed": bool(not missed_must
                       and len(non_must_missed) <= miss_budget
                       and cm["f1"] >= gt["f1_threshold"]),
        "graded_reward": 0.0 if missed_must else round(cm["f1"], 4),
    }
    print(f"NOISEBENCH_METRICS {json.dumps(metrics, sort_keys=True)}")
    try:
        if os.path.isdir(os.path.dirname(METRICS_PATH)):
            with open(METRICS_PATH, "w") as f:
                json.dump(metrics, f, indent=1)
    except OSError:
        pass  # metrics file is best-effort; never fail grading over it


# --- pytest entrypoints -------------------------------------------------------

def test_cardinal_no_real_sev_suppressed():
    """Suppressing any must-page real incident is an automatic fail."""
    _, _, missed_must, _, _ = _evaluate()
    assert not missed_must, (
        f"CARDINAL FAILURE: real high-severity incident(s) suppressed: {missed_must}. "
        f"Reward 0 regardless of F1.")


def test_miss_budget():
    _, _, _, non_must_missed, miss_budget = _evaluate()
    assert len(non_must_missed) <= miss_budget, (
        f"Missed {len(non_must_missed)} non-must real incidents "
        f"({non_must_missed}), budget is {miss_budget}.")


def test_f1_threshold():
    gt, cm, _, _, _ = _evaluate()
    assert cm["f1"] >= gt["f1_threshold"], (
        f"F1 {cm['f1']:.3f} below threshold {gt['f1_threshold']:.2f}.")


if __name__ == "__main__":
    try:
        test_cardinal_no_real_sev_suppressed()
        test_miss_budget()
        test_f1_threshold()
        print("\nAll NoiseBench checks passed.")
        sys.exit(0)
    except AssertionError as e:
        print(f"\nTest failed: {e}")
        sys.exit(1)
