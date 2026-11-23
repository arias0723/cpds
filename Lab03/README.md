# Lab03 — Paxy (Paxos in Erlang)

## 1. Compile and run locally

```bash
cd Lab03/src
erlc *.erl
erl
```
```erlang
1> paxy:start([1000, 2000, 3000]).   % sleep (ms) for Fry, Bender, Leela
2> paxy:crash(homer).                % crash + recover an acceptor (state from disk)
3> paxy:stop().                      % always stop before the next start
```

## 2. Distributed run (acceptors on paxy-acc, proposers on paxy-pro)

Three terminals in `Lab03/src`, same cookie. Use `@localhost` if a plain
`-sname paxy-acc` gives `pang` on `net_adm:ping` (host name resolving to a LAN IP):

```bash
erl -sname paxy-acc@localhost -setcookie paxy     # terminal 1
erl -sname paxy-pro@localhost -setcookie paxy     # terminal 2
erl -sname paxy@localhost     -setcookie paxy     # terminal 3 (GUI)
```
```erlang
(paxy@localhost)1> paxy:start_dist([1000, 2000, 3000]).
(paxy@localhost)2> paxy:crash_dist(marge).
(paxy@localhost)3> paxy:stop_dist().
```

## 3. Experiment switches (compile-time)

| Flag | Effect |
|---|---|
| `-Dpromise_delay=D` / `-Dvote_delay=D` | delay promise / vote by rand in [1, D] ms |
| `-Dpromise_drop=P` / `-Dvote_drop=P` | drop P % of promise / vote messages |
| `-Dno_sorry` | acceptor never sends sorry |
| `-Dtimeout=T` | proposer timeout (default 2000 ms) |
| `-Dno_sorry_abort` | basic proposer (ignore sorry, wait for timeout) |

Example: `erlc -Dvote_drop=20 -Dno_sorry_abort *.erl`

## 4. Reproduce the report's experiments

```bash
cd Lab03
experiments/run_experiments.sh 20 16     # 62 configs x 20 trials, ~18 min
python3 experiments/summarize.py         # -> experiments/summary.csv
(cd experiments/runs/base && erl -noshell -pa ../../../build/base -eval 'bench:ft_test(), halt().')  # crash-recovery check
latexmk -pdf report.tex
```
