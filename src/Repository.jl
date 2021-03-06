"Allows saving and loading data to and from the cache(s)"
module Repository

using BSONqs
const BSON = BSONqs
using Redis
import Dates: Second, Period
import Base.Threads: Atomic, atomic_cas!, atomic_xchg!
import Sockets: TCPSocket

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
    cs = rconns::Vector{SharedConnection}

    for conn in cs
        if atomic_cas!(conn.lock, 0, 1) == 0
            return conn
        end
    end

    if MAX_CONNECTIONS < length(cs)
        error("Redis connection limit ($MAX_CONNECTIONS) reached")
    end

    @debug "Creating Redis connection" length(cs)
    dconf = Conf.get_conf(:data)
    conn = SharedConnection(
        Atomic{Int}(1),
        RedisConnection(;host=get(dconf, "host", "127.0.0.1")::String,
                        password=get(dconf, "auth", "")::String))
    push!(cs, conn)

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
                break
            catch exception
                @debug "Could not get connection" exception
                sleep(0.1)
            end
        end
        if rconn == nothing
            @error "Could not start Redis: $rproc: \n" read(rlog, String)
            return
        end
        rconn
    end

    msg = nothing
    exception = nothing
    for _ in 1:10
        try
            msg = echo(con.conn, "Echo from $(getpid())")
            break
        catch exp
            exception = exp
            @debug "Echo failed" exception
            sleep(1)
        end
    end

    atomic_xchg!(con.lock, 0);

    if msg == nothing
        exception ≠ nothing && rethrow(exception)
        error("Echo to Redis failed, but there is no exception!")
    else
        @debug "Echoed back from Redis" msg
    end
end

function keys(pattern::String)::Vector{String}
    res = with_conn() do conn
        String.(Redis.execute_command(conn, ["keys", pattern]))
    end
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
        BSON.Document(IOBuffer(res), I)[I.name.name]
    end
end

function mload(pattern::String, T::Type{I})::Vector{I} where {I <: AbstractItem}
    mload(keys(pattern), T)
end

function readtocrlf(sk::TCPSocket)::Vector{UInt8}
    seencr = false
    l = Base.StringVector(0)

    while !eof(sk)
        c = read(sk, UInt8)

        if c == 0x0d
            @assert !seencr "Already seen CR"
            seencr = true
        elseif c == 0x0a
            @assert seencr "Got LF, but not seen CR"
            return l
        else
            @assert !seencr "Expected LF, but got $(Char(c))"
            push!(l, c)
        end
    end

    error("Unexpected eof after: $(String(l))")
end

function mload(keys, ::Type{I})::Vector{I} where {I <: AbstractItem}
    if isempty(keys)
        I[]
    else
        ret = Vector{I}(undef, length(keys))

        with_conn() do conn
            Redis.execute_command_without_reply(conn, ["mget", keys...])

            # Bypass the Redis library for reading the item array because it
            # would be difficult to optimise it for this
            l = readtocrlf(conn.socket)
            @assert l[1] == UInt8('*') "Expected array response"
            l[1] = UInt8('0')
            count = parse(Int64, String(l))
            @assert count == length(keys)

            for (i, key) in enumerate(keys)
                l = readtocrlf(conn.socket)
                @assert l[1] == UInt8('$') "Expected bulk string (\$), but got $(Char(l[1]))"
                l[1] = UInt8('0')
                len = parse(Int64, String(l))

                item = read(conn.socket, len + 2)
                @assert length(item)-2 == len "Read bytes $(length(l)) ≠ specified bytes $len"
                @assert item[end-1] == 0x0d && item[end] == 0x0a "crlf should follow"
                resize!(item, length(item)-2)

                try
                    ret[i] = BSON.Document(IOBuffer(item), I)[I.name.name]
                catch exception
                    @error "Raising item" key exception
                end
            end
        end

        ret
    end
end

function drop(pattern::String)::Integer
    ids = keys(pattern)
    isempty(ids) && return 0

    with_conn() do conn
        del(conn, ids...)
    end
end

refresh(t::Tracker.Instance{S}, bref::BugRefs.Ref) where {S} =
    @warn "Refresh BugRefs not defined for tracker $(t.tla) and $S"

"Refresh and return the bug referenced by bref"
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
        s = get(conn, key)
        s === nothing ? s : String(s)
    end
end

end
