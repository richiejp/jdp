module Repository

using BSON
using Redis

"Some kind of item tracked by a tracker"
abstract type AbstractItem end

rconn = nothing

function resetconn()
    global rconn = nothing
end

function getconn()::RedisConnection
    global rconn

    if rconn == nothing
        rconn = RedisConnection()
    end

    rconn
end

keys(pattern::String)::Set{AbstractString} = Redis.keys(getconn(), pattern)

function store(key::String, value::I)::Bool where {I <: AbstractItem}
    buf = IOBuffer()
    bson(buf, Dict(I.name.name => value))
    set(getconn(), key, String(take!(buf)))
end

function load(key::String, ::Type{I})::I where {I <: AbstractItem}
    res = get(getconn(), key)
    BSON.load(IOBuffer(res))[I.name.name]
end

function fetch(item::I,
               in_container::C,
               from::Union{String, Vector{String}};
               kwargs...) where {I <: AbstractItem, C}
    error("Repository.fetch needs to be overriden for $I and $C")
end

end
