-module(inet_free_port_test).

-include_lib("eunit/include/eunit.hrl").

%% Helpers
start_server(Name, Params) ->
    {ok, Pid} = inet_free_port:start_link(Name, Params),
    Pid.

stop_server(Name) ->
    catch gen_server:call(Name, stop),
    ok.

%%--------------------------------------------------------------------
%% Basic tests
%%--------------------------------------------------------------------
get_udp_tcp_port_test() ->
    Name = test_tcp,
    start_server(Name, [{tcp, {30000, 30100}}, {udp, {30000, 30100}}]),
    {ok, Port} = inet_free_port:get_port(Name, tcp),
    ?assert(Port >= 30000),
    ?assert(Port =< 30100),
    {ok, PortUdp} = inet_free_port:get_port(Name, udp),
    ?assert(PortUdp >= 30000),
    ?assert(PortUdp =< 30100),
    stop_server(Name).

get_tcp_port_test() ->
    Name = test_tcp,
    start_server(Name, [{tcp, {30000, 30100}}]),
    {ok, Port} = inet_free_port:get_port(Name, tcp),
    ?assert(Port >= 30000),
    ?assert(Port =< 30100),
    {ok, Port2} = inet_free_port:get_port(Name, tcp),
    ?assertEqual(Port2, 30001),
    {ok, Port3} = inet_free_port:get_port(Name, tcp),
    ?assertEqual(Port3, 30002),
    stop_server(Name).

get_udp_port_test() ->
    Name = test_udp,
    start_server(Name, [{udp, {31000, 31100}}]),
    {ok, Port} = inet_free_port:get_port(Name, udp),
    ?assert(Port >= 31000),
    ?assert(Port =< 31100),
    {ok, Port2} = inet_free_port:get_port(Name, udp),
    ?assertEqual(Port2, 31001),
    {ok, Port3} = inet_free_port:get_port(Name, udp),
    ?assertEqual(Port3, 31002),
    stop_server(Name).

%%--------------------------------------------------------------------
%% Default behavior
%%--------------------------------------------------------------------

default_tcp_test() ->
    Name = test_default,
    start_server(Name, []),
    {ok, Port} = inet_free_port:get_port(Name),
    ?assert(is_integer(Port)),
    ?assert(Port >= 1),
    ?assert(Port =< 65535),
    stop_server(Name).

%%--------------------------------------------------------------------
%% Sequential allocation
%%--------------------------------------------------------------------

sequential_ports_test() ->
    Name = test_seq,
    start_server(Name, [{tcp, {32000, 32010}}]),
    {ok, P1} = inet_free_port:get_port(Name, tcp),
    {ok, P2} = inet_free_port:get_port(Name, tcp),
    ?assert(P2 >= P1),
    stop_server(Name).

%%--------------------------------------------------------------------
%% Limit finder test
%%--------------------------------------------------------------------

limit_finder_test() ->
    Name = test_limit,
    start_server(Name, [{tcp, {33000, 33000}}]),
    {ok, Sock} = gen_tcp:listen(33000, []),
    Result = inet_free_port:get_port(Name, tcp),
    ?assertMatch({error, _}, Result),
    gen_tcp:close(Sock),
    stop_server(Name).

%%--------------------------------------------------------------------
%% Invalid range fallback
%%--------------------------------------------------------------------

invalid_range_test() ->
    Name = test_invalid,
    start_server(Name, [{tcp, {0, 70000}}]),
    {ok, Port} = inet_free_port:get_port(Name, tcp),
    ?assert(Port >= 1),
    ?assert(Port =< 65535),
    stop_server(Name).

%%--------------------------------------------------------------------
%% Timeout test
%%--------------------------------------------------------------------

timeout_test() ->
    Name = test_timeout,
    start_server(Name, [{tcp, {34000, 34100}}]),
    {ok, Port} = inet_free_port:get_port(Name, tcp, 1000),
    ?assert(is_integer(Port)),
    stop_server(Name).

%%    ?debugFmt("Port2 ~p", [Port2]), 
