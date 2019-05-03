"Allows saving and loading data to and from the cache(s)"
module Repository

using BSON
using Redis
import Dates: Second, Period
import Base.Threads: Atomic, atomic_cas!, atomic_xchg!

import JDP.Functional: cmap, c
using JDP.Conf
using JDP.BugRefs
using JDP.Tracker

"Some kind of item tracked by a tracker"
abstract type AbstractItem end

"""A wrapped Redis connection with associated lock

This is accessed using [`getconn`](@ref) and [`with_conn`](@ref), which get a
connection from the (very simple) connection pool.

The lock allows us to make calls to Redis inside [`@async`](@ref) and
[`@spawn`](@ref) blocks.
"""
mutable struct SharedConnection
    lock::Atomic{Int}
    conn::RedisConnection
end

const MAX_CONNECTIONS = 8

rconns = SharedConnection[]

"Use [`with_conn`](@ref)"
function getconn()::SharedConnection
    global rconns

    for conn in rconns
        if atomic_cas!(conn.lock, 0, 1) == 0
            return conn
        end
    end

    if MAX_CONNECTIONS < length(rconns)
        error("Redis connection limit ($MAX_CONNECTIONS) reached")
    end

    @debug "Creating Redis connection" length(rconns)
    dconf = Conf.get_conf(:data)
    conn = SharedConnection(
        Atomic{Int}(1),
        RedisConnection(;host=get(dconf, "host", "127.0.0.1"),
                        password=get(dconf, "auth", "")))
    push!(rconns, conn)

    conn
end

"""Do something with a Redis connection

```julia
with_conn(fun::Function)
```

Run the function `fun(conn::RedisConnection)::Any` with the connection `conn`
from the connection pool. Returning the connection to the pool before returning.

## Example

```julia
ret = with_conn() do conn
    echo(conn, "foo")
end
@assert ret == "foo"
```

Returns the return value of `fun`.
"""
function with_conn(fun::Function)
    conn = getconn()
    ret = fun(conn.conn)
    atomic_xchg!(conn.lock, 0)
    ret
end

function init()
    con = try
        getconn()
    catch e
        if !(e isa ConnectionException)
            rethrow()
        end
        @warn "Could not connect to local Redis instance, will try starting one."
        ddir = Conf.data(:datadir)
        rlog = joinpath(ddir, "redis.log")
        dconf = Conf.get_conf(:data)
        mhost = get(dconf, "master-host", "")
        mauth = get(dconf, "master-auth", "")
        cmd = if isempty(mhost)
            `/usr/sbin/redis-server`
        else
            `/usr/sbin/redis-server --slaveof $mhost 6379 --masterauth $mauth --slave-read-only no`
        end
        rproc = run(pipeline(Cmd(cmd; dir=ddir);
                             stdout=rlog,
                             stderr=rlog); wait=false)

        rconn = nothing
        for _ in 1:10
            try
                rconn = getconn()
            catch
                sleep(0.1)
            end
        end
        if rconn == nothing
            @error "Could not start Redis: $rproc: \n" read(rlog, String)
            return
        end
        rconn
    end

    msg = echo(con.conn, "Echo from $(getpid())")
    @debug "Echoed back from Redis" msg
    atomic_xchg!(con.lock, 0);
end

function keys(pattern::String)::Vector{String}
    res = with_conn() do conn
        Redis.execute_command(conn, ["keys", pattern])
    end
    convert(Vector{String}, res)
end

function store(key::String, value::Dict)::Bool
    buf = IOBuffer()
    bson(buf, value)
    with_conn() do conn
        set(conn, key, String(take!(buf)))
    end
end

function store(key::String, value::I)::Bool where {I <: AbstractItem}
    buf = IOBuffer()
    bson(buf, Dict(I.name.name => value))
    with_conn() do conn
        set(conn, key, String(take!(buf)))
    end
end

function load(key::String, ::Type{Dict})::Dict
    res = with_conn() do conn
        get(conn, key)
    end
    BSON.load(IOBuffer(res))
end

function load(key::String, ::Type{I})::Union{I, Nothing} where {I <: AbstractItem}
    res = with_conn() do conn
        get(conn, key)
    end
    if res != nothing
        BSON.load(IOBuffer(res))[I.name.name]
    end
end

function mload(pattern::String, T::Type{I})::Vector{I} where {I <: AbstractItem}
    mload(keys(pattern), T)
end

function mload(keys, ::Type{I})::Vector{I} where {I <: AbstractItem}
    if isempty(keys)
        I[]
    else
        res = with_conn() do conn
            mget(conn, keys...)
        end
        [BSON.load(IOBuffer(item))[I.name.name] for
         item in res if item != nothing]
    end
end

refresh(t::Tracker.Instance{S}, bref::BugRefs.Ref) where {S} =
    @warn "Refresh BugRefs not defined for tracker $(t.tla) and $S"

refresh(bref::BugRefs.Ref) = refresh(bref.tracker, bref)

"""Refresh the local cached data for the given item(s)

What data is updated depends on the type of item being refreshed. For items
which are logically containers of other items, it may be the contained items
which are updated.
"""
refresh(t::Tracker.Instance{S}, item::I) where {S, I <: AbstractItem} =
    error("Refresh $I not defined for tracker $(t.tla) and $S")

"Refresh the local cached data for the given bug references"
function refresh(bugrefs::Vector{BugRefs.Ref})::Vector
    enumerate(bugrefs) |> cmap() do (indx, bref)
        @info "GET bug $bref ($indx/$(length(bugrefs)))"
        refresh(bref.tracker, bref)
    end
end

refresh(t::Tracker.Instance{S}, items::Vector{I}) where {S, I <: AbstractItem} =
    map(c(refresh)(t), items)

function refresh(items::Vector{I}, from::String) where {I <: AbstractItem}
    tracker = Tracker.get_tracker(Tracker.load_trackers(), from)
    refresh(tracker, from)
end

"""Get one or more items of the given in the specified container

The exact behaviour depends on what is requested. If the data can not be
retrieved from the local data cache then it may request it from a remote
source.
"""
function fetch(item::I,
               in_container::C,
               from::Union{String, Vector{String}};
               kwargs...) where {I <: AbstractItem, C}
    error("Repository.fetch needs to be overriden for $I and $C")
end

fetch(item::I, bref::BugRefs.Ref) where {I <: AbstractItem} =
    error("Repository.fetch needs to be overriden for $I and BugRefs.Ref")

function fetch(bref::BugRefs.Ref)::Union{Nothing, AbstractItem}
    bt = Tracker.get_bug_type(bref.tracker)
    if bt != nothing
        fetch(bt, bref)
    else
        @error "No bug type defined for tracker in bugref $bref"
        nothing
    end
end

function set_temp_flag(name::String, value::String, ttl::Period)
    with_conn() do conn
        key = "temp-flags-$name"
        set(conn, key, value::String)
        expire(conn, key, Second(ttl).value)
    end
end

function get_temp_flag(name::String)::Union{String, Nothing}
    with_conn() do conn
        key = "temp-flags-$name"
        get(conn, key)
    end
end

end
