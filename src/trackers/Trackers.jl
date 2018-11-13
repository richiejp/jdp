module Trackers

export Api, Tracker, TrackerRepo, get_tracker, load_trackers

include("Bugzilla.jl")
#include("Redmine.jl")
include("OpenQA.jl")

using JDP.Conf
using JDP.Templates

abstract type AbstractSession end
struct StaticSession <: AbstractSession end

struct Api{T <: AbstractSession}
    name::String
    get_bug_html::Union{Nothing, Template}
end

ensure_login!(::Tracker{S})::Bool where S <: AbstractSession =
    error("ensure_login! needs to be defined for Tracker{$S}")

ensure_login!(t::Tracker{StaticSession})::StaticSession =
    t.session = StaticSession()

Base.:(==)(a::Api, ao::Api) = a.name == ao.name

mutable struct Tracker{S <: AbstractSession}
    api::Union{Nothing, Api{S}}
    session::Union{Nothing, S}
    tla::String
    scheme::Union{Nothing, String}
    host::Union{Nothing, String}
end

Tracker(tla::String) = Tracker(nothing, nothing, tla, nothing, nothing)
Tracker(tla::SubString)::Tracker = Tracker(String(tla))

Base.:(==)(t::Tracker, to::Tracker) =
    t.api == to.api && t.tla == to.tla && t.host == to.host

function write_get_bug_html_url(io::IO, tracker::Tracker, id::AbstractString)
    write(io, tracker.scheme, "://", tracker.host)
    render(io, tracker.api.get_bug_html, :id => id)
end

struct TrackerRepo
    apis::Dict{String, Api}
    instances::Dict{String, Tracker}
end

get_tracker(repo::TrackerRepo, tla::AbstractString)::Tracker = get(repo.instances, tla) do
    Tracker(tla)
end

mapdic(fn, m) = map(fn, zip(keys(m), values(m))) |> Dict
get_session_type(tracker::String) = try
    getproperty(Trackers, Symbol(tracker)) |> getproperty(:Session)
catch e
    @debug "No tracker session type for $tracker: $e"
    StaticSession
end

function load_trackers()::TrackerRepo
    conf = Conf.get_conf(:trackers)

    tryget(api, thing) = haskey(api, thing) ? Template(api[thing]) : nothing

    apis = mapdic(conf["apis"]) do (name, api)
        name => Api{get_session_type(name)}(name, tryget(api, "get-bug-html"))
    end

    insts = mapdic(conf["instances"]) do (name, inst)
        name => Tracker(get(apis, get(inst, "api", nothing), nothing),
                        nothing,
                        get(inst, "tla", name),
                        get(inst, "scheme", haskey(inst, "host") ? "https" : nothing),
                        get(inst, "host", nothing))
    end

    TrackerRepo(apis, insts)
end

end #module
