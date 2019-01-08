module Repository

using BSON
using Redis

"Some kind of item tracked by a tracker"
abstract type AbstractItem end

rconn = nothing

function store(key::String, value::I)::Bool where {I <: AbstractItem}
    global rconn

    if rconn == nothing
        rconn = RedisConnection()
    end

    buf = IOBuffer()
    bson(buf, Dict(I.name.name => value))
    set(rconn, key, String(take!(buf)))
end

function load(key::String, ::Type{I})::I where {I <: AbstractItem}
    global rconn

    if rconn == nothing
        rconn = RedisConnection()
    end

    res = get(rconn, key)
    BSON.load(IOBuffer(res))[I.name.name]
end

function fetch(item::I,
               in_container::C,
               from::Union{String, Vector{String}};
               kwargs...) where {I <: AbstractItem, C}
    error("Repository.fetch needs to be overriden for $I and $C")
end

end
