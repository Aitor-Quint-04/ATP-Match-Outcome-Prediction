#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generic ETL runner for ATP project

Runs one of: tournaments | players | matches | stats | all

Examples:
  python etl_runner.py tournaments --year 2025
  python etl_runner.py players --year 2024
  python etl_runner.py all --year 2023

Notes:
- Tournaments default year: current year if not provided.
- Players/Matches/Stats default year: None (extractor decides).
- Tries to call .load() / .run() / .extract() in that order.
- Adds common repo paths to sys.path to make imports robust.
"""

import argparse
import inspect
import sys
import time
import traceback
from datetime import datetime
from typing import Any, Optional

# ---- make imports robust whether you run from repo root or subfolder ----
from pathlib import Path
HERE = Path(__file__).resolve().parent
REPO = HERE
CANDIDATE_PATHS = [
    REPO,
    REPO / "ETL",
    REPO / "ETL" / "Extractor",
]
for p in CANDIDATE_PATHS:
    p_str = str(p)
    if p.exists() and p_str not in sys.path:
        sys.path.insert(0, p_str)

# ---- imports (defensive) --------------------------------------------------
def import_or_none(path: str, name: str):
    try:
        module = __import__(path, fromlist=[name])
        return getattr(module, name)
    except Exception:
        return None

TournamentsATPExtractor = (
    import_or_none("ETL.Extractor.TournamentsATPExtractor", "TournamentsATPExtractor")
    or import_or_none("TournamentsATPExtractor", "TournamentsATPExtractor")
)
PlayersATPExtractor = (
    import_or_none("ETL.Extractor.PlayersATPExtractor", "PlayersATPExtractor")
    or import_or_none("PlayersATPExtractor", "PlayersATPExtractor")
)
MatchesATPExtractor = (
    import_or_none("ETL.Extractor.MatchesATPExtractor", "MatchesATPExtractor")
    or import_or_none("MatchesATPExtractor", "MatchesATPExtractor")
)
StatsATPExtractor = (
    import_or_none("ETL.Extractor.StatsATPExtractor", "StatsATPExtractor")
    or import_or_none("StatsATPExtractor", "StatsATPExtractor")
)

# ---- utils ----------------------------------------------------------------
def log(msg: str) -> None:
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)

def build_instance(cls: Any, year: Optional[str]):
    """Instantiate extractor.
    Passes `year` only if the constructor accepts it, otherwise instantiates with no args.
    """
    if cls is None:
        return None
    try:
        sig = inspect.signature(cls)
        if "year" in sig.parameters:
            return cls(year)
        # if it accepts *args/**kwargs, still pass year as positional
        params = sig.parameters.values()
        if any(p.kind in (p.VAR_POSITIONAL, p.VAR_KEYWORD) for p in params):
            return cls(year)
        return cls()
    except Exception:
        # Fallback no-arg
        try:
            return cls()
        except Exception:
            raise

def run_component(tag: str, cls: Any, year: Optional[str]) -> bool:
    """Run a single extractor class with detailed prints and timing."""
    log(f"=== {tag}: START ===")
    if cls is None:
        log(f"[WARN] {tag}: extractor class not found. Verify file & class names.")
        return False

    start = time.time()
    try:
        log(f"{tag}: resolving instance (year={year}) ...")
        inst = build_instance(cls, year)
        log(f"{tag}: instance -> {inst.__class__.__name__}")

        # try common method names in order
        for m in ("load", "run", "extract", "execute"):
            if hasattr(inst, m) and callable(getattr(inst, m)):
                log(f"{tag}: calling .{m}() ...")
                getattr(inst, m)()
                break
        else:
            raise AttributeError(
                f"{tag}: no runnable method found (.load/.run/.extract/.execute)."
            )

        elapsed = time.time() - start
        log(f"=== {tag}: DONE in {elapsed:.2f}s ===")
        return True

    except Exception as e:
        elapsed = time.time() - start
        log(f"[ERROR] {tag} failed after {elapsed:.2f}s: {e}")
        traceback.print_exc()
        return False

# ---- CLI ------------------------------------------------------------------
def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="etl_runner",
        description="Run ATP ETL extractors: tournaments | players | matches | stats | all",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p1 = sub.add_parser("tournaments", help="Run TournamentsATPExtractor")
    p1.add_argument("--year", type=str, default=None, help="Year (default: current year)")

    p2 = sub.add_parser("players", help="Run PlayersATPExtractor")
    p2.add_argument("--year", type=str, default=None, help="Year (optional)")

    p3 = sub.add_parser("matches", help="Run MatchesATPExtractor")
    p3.add_argument("--year", type=str, default=None, help="Year (optional)")

    p4 = sub.add_parser("stats", help="Run StatsATPExtractor")
    p4.add_argument("--year", type=str, default=None, help="Year (optional)")

    p5 = sub.add_parser("all", help="Run all extractors in sequence")
    p5.add_argument("--year", type=str, default=None, help="Year for all (tournaments defaults to current year if omitted)")
    return parser

def main():
    parser = make_parser()
    args = parser.parse_args()

    log("Bootstrapping ETL runner ...")
    log(f"Command: {args.cmd} | Year: {getattr(args, 'year', None)}")

    ok_all = True

    if args.cmd == "tournaments":
        year = args.year or str(datetime.today().year)
        ok_all &= run_component("TOURNAMENTS", TournamentsATPExtractor, year)

    elif args.cmd == "players":
        ok_all &= run_component("PLAYERS", PlayersATPExtractor, args.year)

    elif args.cmd == "matches":
        ok_all &= run_component("MATCHES", MatchesATPExtractor, args.year)

    elif args.cmd == "stats":
        ok_all &= run_component("STATS", StatsATPExtractor, args.year)

    elif args.cmd == "all":
        # tournaments gets current year by default if not provided
        year_tour = args.year or str(datetime.today().year)
        year_other = args.year  # may be None → extractor decides

        log("Running ALL components in order: TOURNAMENTS → PLAYERS → MATCHES → STATS")
        ok_all &= run_component("TOURNAMENTS", TournamentsATPExtractor, year_tour)
        ok_all &= run_component("PLAYERS",     PlayersATPExtractor,     year_other)
        ok_all &= run_component("MATCHES",     MatchesATPExtractor,     year_other)
        ok_all &= run_component("STATS",       StatsATPExtractor,       year_other)

    log("ETL runner finished.")
    if ok_all:
        log("STATUS: SUCCESS ✅")
        sys.exit(0)
    else:
        log("STATUS: PARTIAL/FAILED ❌  (check logs above)")
        sys.exit(1)

if __name__ == "__main__":
    main()
