%%% ===================================================================
%%% Acceptor (Paxos) -- fault-tolerant version
%%%
%%% Passive role: it only reacts to proposer messages. Its whole state is
%%%   Promised : highest round it has promised (won't vote below it)
%%%   Voted    : highest round it has actually voted for
%%%   Value    : value (colour) of that highest voted ballot, or na
%%%   PanelId  : pid of the GUI panel that displays this acceptor
%%%
%%% The state is kept on disk (module pers, a dets table named after the
%%% acceptor) so that a crashed acceptor restarts with exactly the same
%%% state it had before failing.
%%% ===================================================================
-module(acceptor).
-export([start/2]).

%%% -------------------------------------------------------------------
%%% Experiment knobs. Defaults give the normal behaviour; override them
%%% at compile time, e.g.  erlc -Dpromise_delay=500 -Dvote_drop=10 ...
%%% -------------------------------------------------------------------
-ifndef(promise_delay).
-define(promise_delay, 0).   % max random delay (ms) of promise messages
-endif.
-ifndef(vote_delay).
-define(vote_delay, 0).      % max random delay (ms) of vote messages
-endif.
-ifndef(promise_drop).
-define(promise_drop, 0).    % % of promise messages dropped
-endif.
-ifndef(vote_drop).
-define(vote_drop, 0).       % % of vote messages dropped
-endif.
%% erlc -Dno_sorry  -> the acceptor never sends sorry messages

%% Spawn the acceptor process; paxy registers the returned pid by Name.
%% PanelId = na means "restart after a crash": recover it from disk.
start(Name, PanelId) ->
  spawn(fun() -> init(Name, PanelId) end).

%% Recovery after a crash: reload the last saved state (including the
%% GUI panel) and show it again on the panel.
init(Name, na) ->
  pers:open(Name),
  {Promised, Voted, Value, PanelId} = pers:read(Name),
  io:format("[Acceptor ~w] RECOVERED promised ~w voted ~w colour ~w~n",
             [Name, Promised, Voted, Value]),
  update_gui(PanelId, Promised, Voted, Value),
  acceptor(Name, Promised, Voted, Value, PanelId);
%% Fresh start: nothing promised, nothing voted. order:null() ({0,0})
%% is lower than any real sequence number, so the first prepare wins.
%% The initial state is saved so that the PanelId is known even if the
%% acceptor crashes before its first promise.
init(Name, PanelId) ->
  pers:open(Name),
  Promised = order:null(),
  Voted = order:null(),
  Value = na,
  save(Name, Promised, Voted, Value, PanelId),
  acceptor(Name, Promised, Voted, Value, PanelId).

%% Main loop: wait for a message, reply, recurse with the (new) state.
acceptor(Name, Promised, Voted, Value, PanelId) ->
  receive

    %% ---------------------------------------------------------------
    %% PHASE 1 -- prepare(Round)
    %% A proposer asks: "promise not to vote in any round below Round".
    %% ---------------------------------------------------------------
    {prepare, Proposer, Round} ->
      case order:gr(Round, Promised) of
        true ->
          %% Round is newer than any promise given -> promise it.
          %% Persist the new promise BEFORE replying: if we crash after
          %% replying, we must not forget what we promised.
          save(Name, Round, Voted, Value, PanelId),
          %% Report our highest vote (Voted, Value) so the proposer can
          %% adopt an already-voted value instead of its own.
          reply(Proposer, {promise, Round, Voted, Value},
                ?promise_delay, ?promise_drop),
      io:format("[Acceptor ~w] Phase 1: promised ~w voted ~w colour ~w~n",
                 [Name, Round, Voted, Value]),
          % Update gui
          update_gui(PanelId, Round, Voted, Value),
          %% New state: Promised := Round
          acceptor(Name, Round, Voted, Value, PanelId);
        false ->
          %% Already promised an equal/higher round -> refuse.
          %% Tag the sorry with Round so the proposer can match it.
          sorry(Proposer, {sorry, {prepare, Round}}),
          %% State unchanged
          acceptor(Name, Promised, Voted, Value, PanelId)
      end;

    %% ---------------------------------------------------------------
    %% PHASE 2 -- accept(Round, Proposal)
    %% A proposer that got a quorum of promises asks us to vote.
    %% ---------------------------------------------------------------
    {accept, Proposer, Round, Proposal} ->
      case order:goe(Round, Promised) of
        true ->
          %% No higher promise blocks this round -> vote for it.
          %% (>= because the round we promised is exactly this one.)
          case order:goe(Round, Voted) of
            true ->
              %% This is our highest ballot so far -> remember it.
              %% Persist before replying (same reason as above).
              save(Name, Promised, Round, Proposal, PanelId),
              reply(Proposer, {vote, Round}, ?vote_delay, ?vote_drop),
      io:format("[Acceptor ~w] Phase 2: promised ~w voted ~w colour ~w~n",
                 [Name, Promised, Round, Proposal]),
              % Update gui: panel takes the colour of the voted value
              update_gui(PanelId, Promised, Round, Proposal),
              %% New state: Voted := Round, Value := Proposal
              %% (Promised is NOT changed by voting)
              acceptor(Name, Promised, Round, Proposal, PanelId);
            false ->
              %% We vote, but for a lower round than one we voted
              %% before -> keep remembering the higher ballot.
              %% State unchanged, so nothing to save.
              reply(Proposer, {vote, Round}, ?vote_delay, ?vote_drop),
              acceptor(Name, Promised, Voted, Value, PanelId)
          end;
        false ->
          %% We promised a higher round -> cannot vote this one.
          sorry(Proposer, {sorry, {accept, Round}}),
          acceptor(Name, Promised, Voted, Value, PanelId)
      end;

    %% ---------------------------------------------------------------
    %% Termination (paxy:stop/0): successful end of execution, so the
    %% saved state is removed from disk; then close our GUI panel.
    %% ---------------------------------------------------------------
    stop ->
      pers:close(Name),
      pers:delete(Name),
      PanelId ! stop,
      ok
  end.

%%% -------------------------------------------------------------------
%%% Helpers
%%% -------------------------------------------------------------------

%% Store the state and force it to disk, so it survives a crash of the
%% acceptor (or of the whole Erlang node) right after this point.
save(Name, Promised, Voted, Value, PanelId) ->
  pers:store(Name, Promised, Voted, Value, PanelId),
  dets:sync(Name).

%% Show the state on the acceptor's panel (black while nothing voted).
update_gui(PanelId, Promised, Voted, Value) ->
  Colour = case Value of na -> {0,0,0}; _ -> Value end,
  PanelId ! {updateAcc, "Voted: " ++ io_lib:format("~p", [Voted]),
             "Promised: " ++ io_lib:format("~p", [Promised]), Colour}.

%% Send a promise/vote, possibly dropping it (Drop % of the time) or
%% delaying it by a random time in [1, Delay] ms (experiments i and iii).
reply(To, Message, Delay, Drop) ->
  P = rand:uniform(100),
  if P =< Drop ->
       io:format("message dropped~n");
     Delay > 0 ->
       T = rand:uniform(Delay),
       timer:send_after(T, To, Message);
     true ->
       To ! Message
  end.

%% Send a sorry message, unless they are disabled (experiment ii).
-ifdef(no_sorry).
sorry(_To, _Message) ->
  ok.
-else.
sorry(To, Message) ->
  To ! Message.
-endif.
