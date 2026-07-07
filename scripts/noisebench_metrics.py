"""Extract per-trial graded metrics from a Harbor trial directory.

The NoiseBench grader emits a graded reward (0.0 on a cardinal must_page
failure, otherwise F1) alongside the binary verdict. Sources, in order:

  1. verifier/metrics.json            — written by graders from 2026-07 on
  2. NOISEBENCH_METRICS line          — grader stdout (test-stdout.txt / pytest.log)
  3. legacy stdout lines              — `precision=.. recall=.. f1=..` +
                                        `missed_must=..` printed by older graders
  4. verifier ran but nothing parses  — grader asserted before scoring (missing/
                                        malformed triage.json): graded reward 0.0
  5. no verifier output at all        — harness error; returns None

Returns a dict with at least {"f1": float|None, "graded_reward": float} or None.
"""
from __future__ import annotations

import ast
import json
import re
from pathlib import Path

_LEGACY_PRF = re.compile(r"precision=([\d.]+)\s+recall=([\d.]+)\s+f1=([\d.]+)")
_LEGACY_MISSED = re.compile(r"missed_must=(none|\[[^\]]*\])")


def _from_stdout(text: str) -> dict | None:
    for line in text.splitlines():
        if line.startswith("NOISEBENCH_METRICS "):
            try:
                return json.loads(line.split(" ", 1)[1])
            except json.JSONDecodeError:
                continue
    prf = _LEGACY_PRF.search(text)
    if not prf:
        return None
    missed: list = []
    m = _LEGACY_MISSED.search(text)
    if m and m.group(1) != "none":
        try:
            missed = ast.literal_eval(m.group(1))
        except (ValueError, SyntaxError):
            missed = ["<unparsed>"]
    f1 = float(prf.group(3))
    return {
        "precision": float(prf.group(1)),
        "recall": float(prf.group(2)),
        "f1": f1,
        "missed_must": missed,
        "graded_reward": 0.0 if missed else f1,
    }


def graded_of(trial_dir: Path) -> dict | None:
    verifier = Path(trial_dir) / "verifier"
    mf = verifier / "metrics.json"
    if mf.exists():
        try:
            return json.loads(mf.read_text())
        except json.JSONDecodeError:
            pass
    for name in ("test-stdout.txt", "pytest.log"):
        f = verifier / name
        if f.exists():
            m = _from_stdout(f.read_text(errors="replace"))
            if m:
                return m
    if (verifier / "reward.txt").exists():
        # Verifier ran but the grader never reached scoring: total failure.
        return {"f1": None, "graded_reward": 0.0}
    return None
