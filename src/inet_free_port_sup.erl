-module(inet_free_port_sup).

-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).
-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 1
    },
    Env = application:get_all_env(inet_free_port),
    ChildSpecs = [
        #{
            id => Name,
            start => {inet_free_port, start_link, [Name, Param]},
            restart => permanent,
            shutdown => brutal_kill,
            type => worker,
            modules => [inet_free_port]
        }
     || {Name, Param} <- Env
    ],
    {ok, {SupFlags, ChildSpecs}}.
