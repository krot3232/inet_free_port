%%% @author Konstantin Rusalov
%%% @copyright (c) 2026 Konstantin Rusalov
-module(inet_free_port).
-moduledoc """
A lightweight Erlang server for finding free TCP and UDP ports
within a specified range.

The server keeps internal state for TCP and UDP port ranges and
returns the next available port on request.

Ports are checked by attempting to bind using `gen_tcp` or `gen_udp`.
If binding succeeds, the port is considered free.

## Features
- Supports TCP and UDP
- Configurable port ranges
- Sequential port search
- Lightweight and dependency-free

## Example

```
StartPort = 1000,
EndPort = 2000,
{ok, _Pid} = inet_free_port:start_link(my_port_server, [
    {tcp, {StartPort, EndPort}},
    {udp, {StartPort, EndPort}}
]).

{ok, TcpPort} = inet_free_port:get_port(my_port_server, tcp).
{ok, UdpPort} = inet_free_port:get_port(my_port_server, udp).
```
""".

-behaviour(application).
-behaviour(gen_server).

-export([start/2, stop/1]).

-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([get_port/1, get_port/2, get_port/3]).

-define(LIMIT_FINDER, 10).
-define(START_PORT, 1).
-define(END_PORT, 65535).
-define(TIME_DEFAULT, 5000).

-doc """
Starts the application inet_free_port
""".
-spec start(term(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    inet_free_port_sup:start_link().

-doc """
Stops the application inet_free_port
""".
-spec stop(term()) -> ok.
stop(_State) ->
    ok.

-doc """
Starts a new inet_free_port server.
* `Name` - Local registered name of the server
* `Param` - Proplist with configuration:
```
[
  {tcp, {StartPort, EndPort}},
  {udp, {StartPort, EndPort}}
]
```
If range is invalid, defaults to `1..65535`.
""".
-spec start_link(atom(), proplists:proplist()) ->
    {ok, pid()} | {error, term()}.
start_link(Name, Param) ->
    gen_server:start_link({local, Name}, ?MODULE, [Param], []).

-doc """
Initializes the server state.
Internal function. Builds state for TCP and UDP ranges.
""".
-spec init([proplists:proplist()]) ->
    {ok, map()}.
init([Param]) ->
    State1 = init_param(udp, #{}, Param),
    State2 = init_param(tcp, State1, Param),
    {ok, State2}.

-doc """
Handles synchronous requests.
 Supported calls:
 - `{get_port, tcp | udp}` – returns a free port
 - `stop` – stops the server
""".
-spec handle_call(term(), {pid(), term()}, map()) ->
    {reply, term(), map()}
    | {stop, term(), term(), map()}.
handle_call({get_port, Type}, _From, State) ->
    Value = maps:get(Type, State),
    case next_port(Type, Value) of
        {ok, Port} -> {reply, {ok, Port}, State#{Type => erlang:setelement(1, Value, Port)}};
        {error, Err} -> {reply, {error, Err}, State}
    end;
handle_call(stop, _From, State) ->
    {stop, normal, stopped, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

-doc false.
-spec handle_cast(term(), map()) ->
    {noreply, map()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

-doc false.
-spec handle_info(term(), map()) ->
    {noreply, map()}.
handle_info(_Info, State) ->
    {noreply, State}.

-doc false.
-spec terminate(term(), map()) -> ok.
terminate(_Reason, _State) ->
    ok.

-doc false.
-spec code_change(term(), map(), term()) ->
    {ok, map()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Internal logic
-doc """
Initializes port range for a given protocol.
Stores tuple `{Current, Start, End}` in state.
""".
-spec init_param(tcp | udp, map(), proplists:proplist()) -> map().
init_param(Type, Map0, Param) ->
    Map0#{
        Type =>
            case proplists:get_value(Type, Param, {0, 0}) of
                {A, B} when A =< 0 orelse B =< 0 orelse A >= 65535 orelse B >= 65535 ->
                    {?START_PORT, ?START_PORT, ?END_PORT};
                {Start, End} ->
                    {Start - 1, Start, End}
            end
    }.

-doc """
Finds next available port using default limit.
""".
-spec next_port(tcp | udp, {integer(), integer(), integer()}) ->
    {ok, inet:port_number()} | {error, limit_finder}.
next_port(Type, Port) -> next_port(Type, Port, ?LIMIT_FINDER).

-spec next_port(tcp | udp, {integer(), integer(), integer()}, non_neg_integer()) ->
    {ok, inet:port_number()} | {error, limit_finder}.
next_port(Type, {CurPort, StartPort, CurPort}, I) ->
    check_port(Type, {StartPort, StartPort, CurPort}, I - 1);
next_port(Type, {CurPort, StartPort, EndPort}, I) ->
    check_port(Type, {CurPort + 1, StartPort, EndPort}, I).

-doc """
Checks if a port is available by attempting to bind.
TCP uses `gen_tcp:listen/2`
UDP uses `gen_udp:open/1`
""".
-spec check_port(tcp | udp, {integer(), integer(), integer()}, non_neg_integer()) ->
    {ok, inet:port_number()} | {error, limit_finder}.
check_port(_Type, _Port, 0) ->
    {error, limit_finder};
check_port(tcp = Type, {CurPort, _, _} = Port, I) ->
    case gen_tcp:listen(CurPort, []) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            {ok, CurPort};
        _ ->
            next_port(Type, Port, I)
    end;
check_port(udp = Type, {CurPort, _, _} = Port, I) ->
    case gen_udp:open(CurPort) of
        {ok, Socket} ->
            gen_udp:close(Socket),
            {ok, CurPort};
        _ ->
            next_port(Type, Port, I)
    end.

%% Public API
-doc """
Returns a free port.
## Parameters
* `Server` - Server name or pid
* `Type` - `tcp` or `udp`
* `Timeout` - timeout in milliseconds
returns `{ok, Port}` or `{error, Reason}`
""".
-spec get_port(atom() | pid(), tcp | udp, timeout()) ->
    {ok, inet:port_number()} | {error, term()}.
get_port(Server, Type, Timeout) when Type =:= tcp; Type =:= udp ->
    gen_server:call(Server, {get_port, Type}, Timeout).

-doc """
Returns a free TCP or UDP port using default timeout (5000 ms).
""".
-doc #{equiv => get_port(Server, Type, 5000)}.
-spec get_port(atom() | pid(), tcp | udp) ->
    {ok, inet:port_number()} | {error, term()}.
get_port(Server, Type) -> get_port(Server, Type, ?TIME_DEFAULT).

-doc """
Returns a free TCP port using default timeout.
""".
-doc #{equiv => get_port(Server, tcp, 5000)}.
-spec get_port(atom() | pid()) ->
    {ok, inet:port_number()} | {error, term()}.
get_port(Server) -> get_port(Server, tcp, ?TIME_DEFAULT).
