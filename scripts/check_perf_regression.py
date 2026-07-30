#!/usr/bin/env python3
"""
check_perf_regression.py - compares the smoke test's per-scene frame-time
numbers against a checked-in baseline and fails if any scene got
meaningfully slower. Catches the kind of regression this project has hit
before (a scene creeping back up toward or past the 60fps/16.6ms line)
without needing a human to eyeball the perf leaderboard after every change.

Usage:
    scripts/check_perf_regression.py                    # compare, exit 1 on regression
    scripts/check_perf_regression.py --update-baseline  # accept current numbers as new baseline
    scripts/check_perf_regression.py --result PATH      # non-default .smoketest_result location

Reads per-scene "perf=<SceneClassName>:<avgMs>" lines that SmokeTest.pde's
printReport() writes into .smoketest_result (one run's worth of data), and
compares against Music_Visualizer_CK/perf_baseline.json (checked into git).

Tolerance is intentionally generous (default 35% relative + 0.5ms absolute
floor) rather than tight, because:
  - CI runs SMOKETEST_QUICK (~10 frames/scene) which is noisier than a full
    local run (~100+ frames/scene) - the baseline is generated from a full
    local run, so CI numbers will legitimately vary more.
  - Shared CI runners have variable background load; a single machine's
    absolute ms numbers aren't perfectly reproducible run to run.
  - The absolute floor avoids flagging trivial noise on already-fast scenes
    (e.g. 0.2ms -> 0.3ms is a 50% jump but meaningless in practice).
This is meant to catch real regressions (a scene creeping from ~5ms to
~11ms), not enforce micro-optimization on every commit.
"""
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_RESULT = REPO_ROOT / "Music_Visualizer_CK/.smoketest_result"
BASELINE_PATH = REPO_ROOT / "Music_Visualizer_CK/perf_baseline.json"

REL_TOLERANCE = 0.35   # allow up to 35% slower before flagging
ABS_FLOOR_MS = 0.5     # ...but only if the absolute increase is also >0.5ms


def parse_result(path):
    if not path.exists():
        raise SystemExit(
            f"{path} not found - run the smoke test first "
            "(./smoketest.sh or touch .smoketest && ./run.sh)."
        )
    perf = {}
    for line in path.read_text().splitlines():
        m = re.match(r"perf=([\w.]+):([\d.]+)", line)
        if m:
            perf[m.group(1)] = float(m.group(2))
    if not perf:
        raise SystemExit(
            f"{path} has no perf= lines - it may be from an older "
            "SmokeTest.pde build. Rebuild and rerun the smoke test."
        )
    return perf


def main():
    args = sys.argv[1:]
    update = "--update-baseline" in args
    result_path = DEFAULT_RESULT
    if "--result" in args:
        result_path = Path(args[args.index("--result") + 1])

    current = parse_result(result_path)

    if update:
        BASELINE_PATH.write_text(
            json.dumps(dict(sorted(current.items())), indent=2) + "\n"
        )
        print(f"Wrote baseline for {len(current)} scenes to {BASELINE_PATH.relative_to(REPO_ROOT)}")
        return

    if not BASELINE_PATH.exists():
        raise SystemExit(
            f"{BASELINE_PATH} does not exist yet - run with --update-baseline "
            "once (after a full local smoke test) to create it."
        )
    baseline = json.loads(BASELINE_PATH.read_text())

    regressions = []
    new_scenes = []
    for name, ms in sorted(current.items(), key=lambda kv: -kv[1]):
        base = baseline.get(name)
        if base is None:
            new_scenes.append(name)
            continue
        allowed = max(base * (1 + REL_TOLERANCE), base + ABS_FLOOR_MS)
        if ms > allowed:
            regressions.append((name, base, ms))

    if new_scenes:
        print(
            "[perf] Note: scene(s) with no baseline entry (new scene, or "
            "baseline is stale): " + ", ".join(new_scenes)
        )
        print("[perf] Run --update-baseline once these are expected to stick around.\n")

    if regressions:
        print(f"[perf] {len(regressions)} scene(s) regressed beyond tolerance "
              f"(>{REL_TOLERANCE*100:.0f}% and >{ABS_FLOOR_MS}ms slower):\n")
        for name, base, ms in regressions:
            pct = (ms / base - 1) * 100
            print(f"  {name:<28} {base:6.2f}ms -> {ms:6.2f}ms  (+{pct:.0f}%)")
        print(
            "\nIf this regression is expected/accepted, run "
            "scripts/check_perf_regression.py --update-baseline and commit "
            "the updated perf_baseline.json."
        )
        sys.exit(1)

    print(f"[perf] No regressions - {len(current)} scenes checked against baseline.")


if __name__ == "__main__":
    main()
