#!/usr/bin/env python3
"""Summarise experiments/results.csv (one line per trial) per configuration.

Output columns (experiments/summary.csv):
  label, acceptors, proposers, trials, consensus  (trials where every
  proposer decided within the time limit), agree (trials where all
  decisions were equal), time_mean / time_median / time_std (ms, over
  trials that reached consensus), rounds_mean / rounds_max (rounds until
  the last proposer decided, over trials that reached consensus).
"""
import csv
import statistics as st
import sys
from collections import OrderedDict
from pathlib import Path

here = Path(__file__).resolve().parent
src = Path(sys.argv[1]) if len(sys.argv) > 1 else here / "results.csv"
dst = here / "summary.csv"

groups = OrderedDict()
with open(src) as f:
    for row in csv.DictReader(f):
        groups.setdefault(row["label"], []).append(row)

with open(dst, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["label", "acceptors", "proposers", "trials", "consensus",
                "agree", "time_mean", "time_median", "time_std",
                "rounds_mean", "rounds_max"])
    for label in sorted(groups):
        rows = groups[label]
        ok = [r for r in rows if r["decided"] == r["proposers"]]
        times = [int(r["time_ms"]) for r in ok]
        rounds = [int(r["max_round"]) for r in ok]
        agree = sum(r["agree"] == "true" for r in rows)
        w.writerow([
            label, rows[0]["acceptors"], rows[0]["proposers"], len(rows),
            len(ok), agree,
            round(st.mean(times)) if times else "",
            round(st.median(times)) if times else "",
            round(st.stdev(times)) if len(times) > 1 else 0,
            f"{st.mean(rounds):.2f}" if rounds else "",
            max(rounds) if rounds else "",
        ])
print(f"wrote {dst}")
