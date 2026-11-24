#!/usr/bin/env bash
# Runs every Paxy experiment of the report with the headless benchmark.
# Each configuration is compiled with its own -D flags into build/<label>
# and run in its own directory (acceptor state files must not collide).
# Results: experiments/results.csv (one line per trial, see bench.erl).
#
# Usage: experiments/run_experiments.sh [trials] [parallel jobs]
set -euo pipefail

LAB="$(cd "$(dirname "$0")/.." && pwd)"
TRIALS="${1:-20}"
JOBS="${2:-12}"
LIMIT=60000                 # ms before a trial is declared "no consensus"
BUILD="$LAB/build"
RUNS="$LAB/experiments/runs"
OUT="$LAB/experiments/results.csv"
BASE="-Dno_sorry_abort"     # basic proposer for sections 2.1 - 2.4

JOBLIST=$(mktemp)
job() { echo "$1|$2|$3|$4" >> "$JOBLIST"; }   # label|flags|acceptors|proposers

# --- baseline -------------------------------------------------------------
job base "$BASE" 5 3

# --- 2.1 message delays (timeout 2000 ms) ----------------------------------
for D in 100 500 1000 2000; do
  job "delay_promise_${D}" "$BASE -Dpromise_delay=$D" 5 3
  job "delay_vote_${D}"    "$BASE -Dvote_delay=$D" 5 3
  job "delay_both_${D}"    "$BASE -Dpromise_delay=$D -Dvote_delay=$D" 5 3
done
# --- 2.1 timeout sweep with both delays of up to 500 ms ---------------------
for T in 250 500 750 1000 4000; do
  job "timeout_${T}_delay_both_500" "$BASE -Dpromise_delay=500 -Dvote_delay=500 -Dtimeout=$T" 5 3
done

# --- 2.2 no sorry messages ------------------------------------------------
job nosorry          "$BASE -Dno_sorry" 5 3
job nosorry_improved "-Dno_sorry" 5 3

# --- 2.3 lost messages ----------------------------------------------------
for P in 10 20 30 40 50 60; do
  job "drop_promise_${P}" "$BASE -Dpromise_drop=$P" 5 3
  job "drop_vote_${P}"    "$BASE -Dvote_drop=$P" 5 3
  job "drop_both_${P}"    "$BASE -Dpromise_drop=$P -Dvote_drop=$P" 5 3
done

# --- 2.4 number of acceptors / proposers ----------------------------------
for A in 3 7 9 15 25 51; do job "acc_${A}" "$BASE" $A 3; done
for P in 1 2 5 7 10 15 20; do job "prop_${P}" "$BASE" 5 $P; done

# --- 2.7 improvement based on sorry messages ------------------------------
for P in 3 5 10; do job "improved_prop_${P}" "" 5 $P; done
for A in 3 15 51; do job "improved_acc_${A}" "" $A 3; done
job improved_delay_both_500 "-Dpromise_delay=500 -Dvote_delay=500" 5 3

# --------------------------------------------------------------------------
rm -f "$OUT"
echo "label,acceptors,proposers,trial,decided,time_ms,max_round,mean_round,agree" > "$OUT.header"

run_one() {
  IFS='|' read -r label flags nacc nprop <<< "$1"
  mkdir -p "$BUILD/$label" "$RUNS/$label"
  # shellcheck disable=SC2086
  erlc -o "$BUILD/$label" $flags "$LAB"/src/*.erl "$LAB/experiments/bench.erl"
  rm -f "$RUNS/$label/part.csv"
  ( cd "$RUNS/$label" && erl -noshell -pa "$BUILD/$label" -eval \
      "bench:run(\"$label\", $nacc, $nprop, $TRIALS, $LIMIT, \"part.csv\"), halt()." \
      > run.log 2>&1 )
  echo "done: $label"
}
export -f run_one
export LAB BUILD RUNS TRIALS LIMIT

tr '\n' '\0' < "$JOBLIST" | xargs -0 -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}

cat "$OUT.header" "$RUNS"/*/part.csv > "$OUT"
rm -f "$OUT.header" "$JOBLIST"
echo "results in $OUT ($(($(wc -l < "$OUT") - 1)) trials)"
