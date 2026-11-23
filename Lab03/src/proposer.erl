%%% ===================================================================
%%% Proposer (Paxos)
%%%
%%% Active role: runs rounds until a majority of acceptors agree on a
%%% value. Each round = one ballot:
%%%   Phase 1: prepare -> collect a quorum of promises
%%%   Phase 2: accept  -> collect a quorum of votes (may be different from the ones
%%%%  that promised at first, but that's ok as long as it is majority)
%%% If either phase fails (timeout, or too many sorry messages), back off
%%% and retry with a higher round.
%%% ===================================================================
-module(proposer).
-export([start/6]).

%% Override at compile time, e.g. erlc -Dtimeout=500
-ifndef(timeout).
-define(timeout, 2000).   % ms to wait for replies in each phase
-endif.
-define(backoff, 10).     % initial max random sleep (ms) after an abort
%% erlc -Dno_sorry_abort -> basic collect/vote: sorry messages are
%% ignored and a failed phase is only detected by the timeout.

%% Spawn the proposer process.
%%   Proposal  : the value (colour) this proposer would like chosen
%%   Acceptors : list of acceptor names (atoms, or {Name, Node} if remote)
%%   Sleep     : initial delay before starting (to stagger proposers)
%%   Main      : process to notify when we decide
start(Name, Proposal, Acceptors, Sleep, PanelId, Main) ->
  spawn(fun() -> init(Name, Proposal, Acceptors, Sleep, PanelId, Main) end).

%% Wait, run rounds until a decision, report it, notify Main and the GUI.
init(Name, Proposal, Acceptors, Sleep, PanelId, Main) ->
  timer:sleep(Sleep),
  Begin = erlang:monotonic_time(),
  %% First sequence number {0, Name}: the Name makes it unique among
  %% proposers (atoms sort above integers, so it is > order:null()).
  Round = order:first(Name),
  {Decision, LastRound} = round(Name, ?backoff, Round, Proposal, Acceptors, PanelId),
  End = erlang:monotonic_time(),
  Elapsed = erlang:convert_time_unit(End-Begin, native, millisecond),
  io:format("[Proposer ~w] DECIDED ~w in round ~w after ~w ms~n",
             [Name, Decision, LastRound, Elapsed]),
  %% Tell Main what was decided, in which round, and how long it took.
  Main ! {done, Name, Decision, LastRound, Elapsed},
  PanelId ! stop.

%% -------------------------------------------------------------------
%% One round = one ballot attempt. Retry forever until a ballot succeeds.
%% -------------------------------------------------------------------
round(Name, Backoff, Round, Proposal, Acceptors, PanelId) ->
  io:format("[Proposer ~w] Phase 1: round ~w proposal ~w~n",
             [Name, Round, Proposal]),
  % Update gui with the round we are starting
  PanelId ! {updateProp, "Round: " ++ io_lib:format("~p", [Round]), Proposal},
  case ballot(Name, Round, Proposal, Acceptors, PanelId) of
    {ok, Value} ->
      %% Consensus reached on Value in this Round.
      {Value, Round};
    abort ->
      %% Ballot failed: sleep a random time (avoids proposers repeatedly
      %% pre-empting each other), then retry with the next round number
      %% and a doubled backoff window (exponential backoff).
      timer:sleep(rand:uniform(Backoff)),
      Next = order:inc(Round),
      round(Name, (2*Backoff), Next, Proposal, Acceptors, PanelId)
  end.

%% -------------------------------------------------------------------
%% A single ballot: Phase 1 (prepare/promise) then Phase 2 (accept/vote).
%% -------------------------------------------------------------------
ballot(Name, Round, Proposal, Acceptors, PanelId) ->
  %% Phase 1a: ask every acceptor for a promise for this Round.
  prepare(Round, Acceptors),
  %% Majority of acceptors (e.g. 3 of 5).
  Quorum = (length(Acceptors) div 2) + 1,
  %% How many sorry messages make a quorum impossible (e.g. 3 of 5).
  MaxSorry = max_sorry(length(Acceptors), Quorum),
  %% Nothing seen voted yet; our own Proposal is the default value.
  MaxVoted = order:null(),
  %% Phase 1b: wait for a quorum of promises.
  case collect(Quorum, Round, MaxVoted, Proposal, MaxSorry) of
    {accepted, Value} ->
      %% Got a quorum. Value is either our Proposal or, if some acceptor
      %% in the quorum had already voted, the value of the highest voted
      %% ballot (Paxos safety rule: never override a possibly-chosen value).
      io:format("[Proposer ~w] Phase 2: round ~w proposal ~w (was ~w)~n",
                 [Name, Round, Value, Proposal]),
      % update gui with the value we will actually propose
      PanelId ! {updateProp, "Round: " ++ io_lib:format("~p", [Round]), Value},
      %% Phase 2a: ask every acceptor to vote for Value in this Round.
      accept(Round, Value, Acceptors),
      %% Phase 2b: wait for a quorum of votes.
      case vote(Quorum, Round, MaxSorry) of
        ok ->
          %% Majority voted -> Value is chosen.
          {ok, Value};
        abort ->
          %% Not enough votes.
          abort
      end;
    abort ->
      %% Not enough promises.
      abort
  end.

%% Improvement (section 4): with Total acceptors and a quorum of Quorum,
%% once Total - Quorum + 1 acceptors said sorry the quorum can no longer
%% be reached, so the ballot can be aborted without waiting the timeout.
-ifdef(no_sorry_abort).
max_sorry(Total, _Quorum) ->
  Total + 1.            % unreachable: never abort because of sorries
-else.
max_sorry(Total, Quorum) ->
  Total - Quorum + 1.
-endif.

%% -------------------------------------------------------------------
%% Phase 1b: collect N promises for Round, tracking the highest voted
%% ballot reported (MaxVoted) and its value (Proposal). Sorry counts how
%% many more refusals we can take before the quorum becomes impossible.
%% -------------------------------------------------------------------
collect(0, _, _, Proposal, _) ->
  %% Quorum reached: return the value to use in Phase 2.
  {accepted, Proposal};
collect(_, _, _, _, 0) ->
  %% Too many sorry messages: a quorum is impossible -> abort now.
  abort;
collect(N, Round, MaxVoted, Proposal, Sorry) ->
  receive
    {promise, Round, _, na} ->
      %% Promise from an acceptor that never voted: counts, no new value.
      collect(N-1, Round, MaxVoted, Proposal, Sorry);
    {promise, Round, Voted, Value} ->
      %% Promise from an acceptor that has voted before.
      case order:gr(Voted, MaxVoted) of
        true ->
          %% Its ballot is the highest seen so far -> adopt its value.
          collect(N-1, Round, Voted, Value, Sorry);
        false ->
          %% Lower than what we already have -> keep current value.
          collect(N-1, Round, MaxVoted, Proposal, Sorry)
      end;
    {promise, _, _,  _} ->
      %% Late promise from an older round -> ignore (don't count).
      collect(N, Round, MaxVoted, Proposal, Sorry);
    {sorry, {prepare, Round}} ->
      %% Refusal for this round -> one refusal closer to giving up.
      collect(N, Round, MaxVoted, Proposal, Sorry-1);
    {sorry, _} ->
      %% Stale refusal from another round/phase -> ignore.
      collect(N, Round, MaxVoted, Proposal, Sorry)
  after ?timeout ->
    %% Quorum not reached in time.
    abort
  end.

%% -------------------------------------------------------------------
%% Phase 2b: collect N votes for Round (Sorry as in collect).
%% -------------------------------------------------------------------
vote(0, _, _) ->
  %% Quorum of votes reached.
  ok;
vote(_, _, 0) ->
  %% Too many sorry messages: a quorum is impossible -> abort now.
  abort;
vote(N, Round, Sorry) ->
  receive
    {vote, Round} ->
      %% Vote for this round -> one closer to the quorum.
      vote(N-1, Round, Sorry);
    {vote, _} ->
      %% Late vote from an older round -> ignore.
      vote(N, Round, Sorry);
    {sorry, {accept, Round}} ->
      %% Refusal for this round -> one refusal closer to giving up.
      vote(N, Round, Sorry-1);
    {sorry, _} ->
      %% Stale refusal (e.g. a late prepare sorry) -> ignore.
      vote(N, Round, Sorry)
  after ?timeout ->
    %% Not enough votes in time.
    abort
  end.

%% -------------------------------------------------------------------
%% Multicast helpers
%% -------------------------------------------------------------------

%% Phase 1a: send prepare(Round) to all acceptors.
prepare(Round, Acceptors) ->
  Fun = fun(Acceptor) ->
    send(Acceptor, {prepare, self(), Round})
  end,
  lists:foreach(Fun, Acceptors).

%% Phase 2a: send accept(Round, Proposal) to all acceptors.
accept(Round, Proposal, Acceptors) ->
  Fun = fun(Acceptor) ->
    send(Acceptor, {accept, self(), Round, Proposal})
  end,
  lists:foreach(Fun, Acceptors).

%% Fault-tolerant send. A remote name {Name, Node} can always be used
%% (sending to a remote process never fails). A local name that is not
%% registered means the acceptor is down: skip it instead of crashing
%% (Name ! Msg would raise badarg).
send(Name, Message) ->
  if is_tuple(Name) -> %remote
    Name ! Message;
  true -> %local
    case whereis(Name) of
      undefined ->
        down;
      Pid ->
        Pid ! Message
    end
  end.
