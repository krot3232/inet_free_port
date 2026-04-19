# inet_free_port
<img src="https://raw.githubusercontent.com/krot3232/logos/main/inet_free_port.png" width="200">
 
A lightweight Erlang/OTP library for finding free TCP and UDP ports within a specified range.

The library runs as an OTP application with a supervisor and one or more gen_server workers, each responsible for managing port allocation.

[![Hex Version](https://img.shields.io/hexpm/v/inet_free_port.svg?style=flat-square)](https://hex.pm/packages/inet_free_port)



## Installation

The package can be installed by adding `inet_free_port` to your list of dependencies
in 
`rebar.config`:
```erlang
{deps, [inet_free_port]}.
```
## Features
+ Find free TCP and UDP ports
+ Configurable port ranges per worker
+ OTP-compliant (application, supervisor, gen_server)
+ Supports multiple independent port
+ Sequential port allocation
+ Lightweight and dependency-free


## Basic usage
**Start application**
```erlang
application:start(inet_free_port).
```
At startup, create workers under the supervisor from `config/sys.config`

The library uses application environment variables to define port.

Example (`config/sys.config`):
```erlang
[
  {inet_free_port, [
    {free_port_server1, [
        {tcp, {30000, 31000}},
        {udp, {31000, 32000}}
    ]}
  ]}
].
```
Each entry creates a separate worker([`inet_free_port`](https://hexdocs.pm/inet_free_port/inet_free_port.html)) under the supervisor([`inet_free_port_sup`](https://hexdocs.pm/inet_free_port/inet_free_port_sup.html)).

---
**Start worker**
```erlang
StartPort = 1000,
EndPort = 2000,
{ok, _Pid} = inet_free_port:start_link(free_port_server1, [
    {tcp, {StartPort, EndPort}},
    {udp, {StartPort, EndPort}}
]).
```
---

**Get a free TCP port**
```erlang
{ok, TcpPort} = inet_free_port:get_port(free_port_server1, tcp).
```
**Get a free UDP port**
```erlang
{ok, UdpPort} = inet_free_port:get_port(free_port_server1, udp).
```
**Default (TCP)**
```erlang
{ok, TcpPort} = inet_free_port:get_port(free_port_server1).
```
**With timeout**
```erlang
{ok, TcpPort} = inet_free_port:get_port(free_port_server1, tcp, 2000).
```
