%%% ===================================================================
%%% Headless benchmark for the Paxy experiments.
%%%
%%% Runs the real acceptor/proposer modules without the wx GUI (panels
%%% are replaced by a process that ignores every message), repeats a
%%% configuration several times and appends one CSV line per trial:
%%%   label,acceptors,proposers,trial,decided,time_ms,max_round,
%%%   mean_round,agree
%%% max_round/mean_round count rounds starting at 1 (round {0,_} = 1).
%%% All proposers start at the same time (sleep 0): worst-case contention.
%%% ===================================================================
-module(bench).
-export([run/6, trial/3, ft_test/0]).

run(Label, NAcc, NProp, Trials, Limit, File) ->
  {ok, F} = file:open(File, [append]),
  lists:foreach(
    fun(T) ->
      {Decided, Time, MaxR, MeanR, Agree} = trial(NAcc, NProp, Limit),
      io:format(F, "~s,~w,~w,~w,~w,~w,~w,~.2f,~w~n",
                [Label, NAcc, NProp, T, Decided, Time, MaxR, MeanR, Agree])
    end,
    lists:seq(1, Trials)),
  file:close(F).

trial(NAcc, NProp, Limit) ->
  Sink = spawn(fun sink/0),
  Accs = [name("acc", I) || I <- lists:seq(1, NAcc)],
  [file:delete(atom_to_list(A)) || A <- Accs],          % no stale state
  AccPids = [begin P = acceptor:start(A, Sink), register(A, P), P end
             || A <- Accs],
  Self = self(),
  Begin = erlang:monotonic_time(millisecond),
  Props = [proposer:start(name("p", I), I, Accs, 0, Sink, Self)
           || I <- lists:seq(1, NProp)],
  Results = wait(NProp, Begin + Limit, []),
  Time = erlang:monotonic_time(millisecond) - Begin,
  %% tear down: kill undecided proposers, stop acceptors (deletes files)
  [exit(P, kill) || P <- Props],
  Refs = [erlang:monitor(process, P) || P <- AccPids],
  [A ! stop || A <- Accs],
  [receive {'DOWN', R, _, _, _} -> ok end || R <- Refs],
  exit(Sink, kill),
  flush(),
  Rounds = [N + 1 || {_, {N, _}} <- Results],
  Values = lists:usort([V || {V, _} <- Results]),
  Decided = length(Results),
  MaxR = lists:max([0 | Rounds]),
  MeanR = case Rounds of [] -> 0.0; _ -> lists:sum(Rounds) / Decided end,
  {Decided, Time, MaxR, MeanR, length(Values) =< 1}.

wait(0, _, Acc) ->
  Acc;
wait(N, Deadline, Acc) ->
  Left = max(0, Deadline - erlang:monotonic_time(millisecond)),
  receive
    {done, _Name, Decision, Round, _Elapsed} ->
      wait(N - 1, Deadline, [{Decision, Round} | Acc])
  after Left ->
    Acc
  end.

sink() ->
  receive _ -> sink() end.

flush() ->
  receive _ -> flush() after 0 -> ok end.

name(Prefix, I) ->
  list_to_atom(Prefix ++ integer_to_list(I)).

%%% -------------------------------------------------------------------
%%% Fault-tolerance check: drive one acceptor by hand, crash it with
%%% paxy:crash/1 and verify it comes back with exactly the same state.
%%% -------------------------------------------------------------------
ft_test() ->
  Panel = spawn(fun panel_log/0),
  file:delete("homer"),
  register(homer, acceptor:start(homer, Panel)),
  Red = {255,0,0},
  homer ! {prepare, self(), {3, fry}},  show(expect()),
  homer ! {accept, self(), {3, fry}, Red}, show(expect()),
  homer ! {prepare, self(), {5, leela}}, show(expect()),
  io:format("--- state file exists: ~w~n", [filelib:is_file("homer")]),
  io:format("--- crashing homer~n"),
  paxy:crash(homer),
  io:format("--- homer restarted as ~w~n", [whereis(homer)]),
  %% promised {5,leela}: a lower prepare must be refused ...
  homer ! {prepare, self(), {4, bender}}, show(expect()),
  %% ... and a higher one must report the vote {3,fry} with Red
  homer ! {prepare, self(), {6, bender}}, show(expect()),
  Ref = erlang:monitor(process, whereis(homer)),
  homer ! stop,
  receive {'DOWN', Ref, _, _, _} -> ok end,
  io:format("--- after stop, state file exists: ~w~n",
            [filelib:is_file("homer")]),
  timer:sleep(100).

expect() ->
  receive M -> M after 1000 -> timeout end.

show(M) ->
  io:format("reply: ~p~n", [M]).

panel_log() ->
  receive
    {updateAcc, V, P, C} ->
      io:format("panel: ~s | ~s | colour ~w~n", [V, P, C]),
      panel_log();
    stop ->
      io:format("panel: stop~n");
    _ ->
      panel_log()
  end.
