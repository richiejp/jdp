module Repository

using BSON
using Redis

import JDP.Functional: cmap
using JDP.Conf
using JDP.BugRefs
using JDP.Tracker

"Some kind of item tracked by a tracker"
abstract type AbstractItem end

rconn = nothing

function resetconn()
    global rconn = nothing
end

function getconn()::RedisConnection
    global rconn

    if rconn == nothing
        dconf = Conf.get_conf(:data)
        rconn = RedisConnection(;host=get(dconf, "host", "127.0.0.1"),
                                password=get(dconf, "auth", ""))
    end

    rconn
end

init() = try
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

    for _ in 1:10
        try
            getconn()
            return
        catch
            sleep(0.1)
        end
    end
    @error "Could not start Redis: $rproc: \n" read(rlog, String)
end

keys(pattern::String)::Vector{String} =
    convert(Vector{String},
            Redis.execute_command(getconn(), ["keys", pattern]))

function store(key::String, value::Dict)::Bool
    buf = IOBuffer()
    bson(buf, value)
    set(getconn(), key, String(take!(buf)))
end

function store(key::String, value::I)::Bool where {I <: AbstractItem}
    buf = IOBuffer()
    bson(buf, Dict(I.name.name => value))
    set(getconn(), key, String(take!(buf)))
end

function load(key::String, ::Type{Dict})::Dict
    res = get(getconn(), key)
    BSON.load(IOBuffer(res))
end

function load(key::String, ::Type{I})::Union{I, Nothing} where {I <: AbstractItem}
    res = get(getconn(), key)
    if res != nothing
        BSON.load(IOBuffer(res))[I.name.name]
    end
end

function mload(pattern::String, ::Type{I})::Vector{I} where {I <: AbstractItem}
    ks = keys(pattern)

    if isempty(ks)
        I[]
    else
        res = mget(getconn(), ks...)
        [BSON.load(IOBuffer(item))[I.name.name] for
         item in res if item != nothing]
    end
end

refresh(t::Tracker.Instance{S}, bref::BugRefs.Ref) where {S} =
    @warn "Refresh not defined for tracker " t.tla " and $S"

function refresh(bugrefs::Vector{BugRefs.Ref})::Vector
    enumerate(bugrefs) |> cmap() do (indx, bref)
        @info "GET bug $bref ($indx/$(length(bugrefs)))"
        refresh(bref.tracker, bref)
    end
end

function fetch(item::I,
               in_container::C,
               from::Union{String, Vector{String}};
               kwargs...) where {I <: AbstractItem, C}
    error("Repository.fetch needs to be overriden for $I and $C")
end

end
