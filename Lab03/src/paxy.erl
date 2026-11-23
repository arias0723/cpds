%%% ===================================================================
%%% Paxy test harness
%%%
%%% Starts the GUI, 5 acceptors and 3 proposers, then waits for every
%%% proposer to decide and prints the total elapsed time.
%%%
%%% Local (one Erlang node):
%%%   paxy:start([1000, 2000, 3000]).  paxy:crash(homer).  paxy:stop().
%%%
%%% Distributed (acceptors on node paxy-acc, proposers on node paxy-pro,
%%% GUI on the node where start_dist is called), all with the same cookie:
%%%   paxy:start_dist([1000, 2000, 3000]).
%%%   paxy:crash_dist(homer).
%%%   paxy:stop_dist().
%%% ===================================================================
-module(paxy).
-export([start/1, stop/0, stop/1, crash/1,
         start_dist/1, stop_dist/0, crash_dist/1]).

%% Proposal values are RGB colours (also used to paint the GUI panels).
-define(RED, {255,0,0}).
-define(BLUE, {0,0,255}).
-define(GREEN, {0,255,0}).

%% Names of the remote Erlang instances (on the same host as the caller).
-define(ACC_NODE, 'paxy-acc').
-define(PRO_NODE, 'paxy-pro').

-define(AccNames, ["Homer", "Marge", "Bart", "Lisa", "Maggie"]).
-define(AccRegister, [homer, marge, bart, lisa, maggie]).
-define(PropNames, [{"Fry", ?RED}, {"Bender", ?GREEN}, {"Leela", ?BLUE}]).
-define(PropInfo, [{fry, ?RED}, {bender, ?GREEN}, {leela, ?BLUE}]).

%%% ===================================================================
%%% Local execution
%%% ===================================================================

% Sleep is a list with the initial sleep time for each proposer
start(Sleep) ->
  AccRegister = ?AccRegister,
  %% 1. Start the GUI and ask it for the pids of its panel processes.
  {AccIds, PropIds} = start_gui(),
  %% 2. Start and register the acceptors (one per acceptor panel).
  start_acceptors(AccIds, AccRegister),
  %% 3. In a separate process (so the shell is not blocked): start the
  %%    proposers, wait for all of them to decide, report time.
  %%    self() here is this spawned process, which receives 'done'.
  spawn(fun() ->
    Begin = erlang:monotonic_time(),
    start_proposers(PropIds, ?PropInfo, AccRegister, Sleep, self()),
    wait_proposers(length(PropIds)),
    End = erlang:monotonic_time(),
    Elapsed = erlang:convert_time_unit(End-Begin, native, millisecond),
    io:format("[Paxy] Total elapsed time: ~w ms~n", [Elapsed])
  end).

%% Start the GUI process and get the pids of its acceptor/proposer panels.
start_gui() ->
  register(gui, spawn(fun() -> gui:start(?AccNames, ?PropNames) end)),
  gui ! {reqState, self()},
  receive
    {reqState, State} ->
      State     % {AccIds, PropIds}
  end.

%% Walk the panel pids and registered names in parallel: spawn each
%% acceptor and register it under its name (proposers address it by name).
start_acceptors(AccIds, AccReg) ->
  case AccIds of
    [] ->
      ok;
    [AccId|Rest] ->
      [RegName|RegNameRest] = AccReg,
      register(RegName, acceptor:start(RegName, AccId)),
      start_acceptors(Rest, RegNameRest)
  end.

%% Walk panel pids, proposer info and sleep times in parallel: spawn each
%% proposer with its colour as proposal and the list of acceptor names.
start_proposers(PropIds, PropInfo, Acceptors, Sleep, Main) ->
  case PropIds of
    [] ->
      ok;
    [PropId|Rest] ->
      [{RegName, Colour}|RestInfo] = PropInfo,
      [FirstSleep|RestSleep] = Sleep,
      proposer:start(RegName, Colour, Acceptors, FirstSleep, PropId, Main),
      start_proposers(Rest, RestInfo, Acceptors, RestSleep, Main)
  end.

%% Block until N 'done' messages arrive (one per decided proposer).
wait_proposers(0) ->
  ok;
wait_proposers(N) ->
  receive
    {done, _Name, _Decision, _Round, _Elapsed} ->
      wait_proposers(N-1)
  end.

%% Acceptors keep running after a decision, so stop them (and the GUI)
%% explicitly.
stop() ->
  lists:foreach(fun stop/1, ?AccRegister),
  stop(gui).

%% Send 'stop' to a registered process if it is still alive. A crashed
%% process is already unregistered, so this never throws.
stop(Name) ->
  case whereis(Name) of
    undefined ->
      ok;
    Pid ->
      Pid ! stop
  end.

%% Simulate a crash of acceptor Name and restart it 3 s later. The new
%% acceptor gets PanelId = na, so it must recover everything (including
%% its panel) from disk. Must run on the node where the acceptors live.
crash(Name) ->
  case whereis(Name) of
    undefined ->
      ok;
    Pid ->
      unregister(Name),
      exit(Pid, "crash"),
      pers:open(Name),
      {_, _, _, Pn} = pers:read(Name),
      Pn ! {updateAcc, "Voted: CRASHED", "Promised: CRASHED", {0,0,0}},
      pers:close(Name),
      timer:sleep(3000),
      register(Name, acceptor:start(Name, na))
  end.

%%% ===================================================================
%%% Distributed execution (part v)
%%% Acceptors and proposers are the same modules as in the local version;
%%% only the place where processes are spawned and the acceptor names
%%% given to the proposers ({Name, Node} instead of Name) change.
%%% ===================================================================

start_dist(Sleep) ->
  AccNode = node_name(?ACC_NODE),
  ProNode = node_name(?PRO_NODE),
  AccRegister = ?AccRegister,
  %% 0. Both remote instances must be up (and share our cookie);
  %%    otherwise we would wait forever for the acceptors' ack.
  [pong = net_adm:ping(N) || N <- [AccNode, ProNode]],
  %% 1. GUI runs on the calling node; panels are plain pids, so remote
  %%    acceptors/proposers can update them transparently.
  {AccIds, PropIds} = start_gui(),
  %% 2. Spawn a process on paxy-acc that creates the acceptors there.
  %%    register/2 is node-local, so the names homer, marge, ... are
  %%    registered on paxy-acc. Wait for its ack before going on, so that
  %%    the proposers are only created once the acceptors are running.
  Self = self(),
  spawn(AccNode, fun() ->
    start_acceptors(AccIds, AccRegister),
    Self ! acceptors_ready
  end),
  receive
    acceptors_ready -> ok
  end,
  %% 3. Remote registered names are addressed as {Name, Node}.
  Acceptors = [{Name, AccNode} || Name <- AccRegister],
  %% 4. Waiter process (local): spawns the proposers on paxy-pro, waits
  %%    for their 'done' messages and reports the total time.
  spawn(fun() ->
    Waiter = self(),
    Begin = erlang:monotonic_time(),
    spawn(ProNode, fun() ->
      start_proposers(PropIds, ?PropInfo, Acceptors, Sleep, Waiter)
    end),
    wait_proposers(length(PropIds)),
    End = erlang:monotonic_time(),
    Elapsed = erlang:convert_time_unit(End-Begin, native, millisecond),
    io:format("[Paxy] Total elapsed time: ~w ms~n", [Elapsed])
  end),
  ok.

%% Stop the remote acceptors (sending to {Name, Node} never fails) and
%% then the local GUI. We wait (max 2 s) until the acceptors are really
%% gone: their last panel updates travel over the network, and closing
%% the window before they arrive would crash the panel processes.
stop_dist() ->
  AccNode = node_name(?ACC_NODE),
  Refs = [begin
            Ref = erlang:monitor(process, {Name, AccNode}),
            {Name, AccNode} ! stop,
            Ref
          end || Name <- ?AccRegister],
  [receive {'DOWN', Ref, _, _, _} -> ok after 2000 -> ok end || Ref <- Refs],
  stop(gui).

%% Run crash/1 on the acceptors' node.
crash_dist(Name) ->
  rpc:call(node_name(?ACC_NODE), paxy, crash, [Name]).

%% 'paxy-acc' -> 'paxy-acc@<host of this node>'
node_name(Short) ->
  [_, Host] = string:split(atom_to_list(node()), "@"),
  list_to_atom(atom_to_list(Short) ++ "@" ++ Host).
