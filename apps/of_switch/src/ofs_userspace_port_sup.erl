%%%-----------------------------------------------------------------------------
%%% Use is subject to License terms.
%%% @copyright (C) 2012 FlowForwarding.org
%%% @doc Supervisor module for ports.
%%% @end
%%%-----------------------------------------------------------------------------
-module(ofs_userspace_port_sup).
-author("Erlang Solutions Ltd. <openflow@erlang-solutions.com>").

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%%%-----------------------------------------------------------------------------
%%% API functions
%%%-----------------------------------------------------------------------------

-spec start_link() -> {ok, pid()} | ignore | {error, term()}.
start_link() ->
    {ok, _} = supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%%-----------------------------------------------------------------------------
%%% Supervisor callbacks
%%%-----------------------------------------------------------------------------

init([]) ->
    ChildSpec = {ofs_userspace_port, {ofs_userspace_port, start_link, []},
                 transient, 5000, worker, [ofs_userspace_port]},
    {ok, {{simple_one_for_one, 5, 10}, [ChildSpec]}}.
