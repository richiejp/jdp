"""Trackers are external sources of information which track some kind of item.

For example Bugzilla and OpenQA are both considered trackers by JDP. Bugzilla
tracks bugs and OpenQA tracks test results. GitWeb could also be considered a
tracker which tracks git commits. Some services may track a number of different
items.

### Design note

Hopefully new trackers can eventually be declaratively defined in
conf/trackers.toml. However this is difficult when most of them seem to use
different authentication methods and different data formats. So we begin with
tracker specific code (e.g. trackers/Bugzilla.jl) and then try to generialise
them if feasible.
"""
module Trackers

export Api, Tracker, TrackerRepo, get_tracker, load_trackers

# Tracker specific files are included in the this module at the end

using JDP.Conf
using JDP.Templates

"A connection to a tracker API"
abstract type AbstractSession end

"Not really a session"
struct StaticSession <: AbstractSession end

"""Information about a tracker's API

This is a generic interface for tracker features which are simple/standard
enough to configure via conf/trackers.toml. Tracker specific features are
handled by Tracker specific methods dispatched on the Session type parameter"""
struct Api{S <: AbstractSession}
    name::String
    get_item_html::Union{Nothing, Template}
end

Base.:(==)(a::Api, ao::Api) = a.name == ao.name

"Information about a Tracker's instance"
mutable struct Tracker{S <: AbstractSession}
    api::Union{Nothing, Api{S}}
    session::Union{Nothing, S}
    tla::String
    scheme::Union{Nothing, String}
    host::Union{Nothing, String}
end

"Create a minimal tracker instance for an unknown tracker"
Tracker(tla::String) =
    Tracker{StaticSession}(nothing, nothing, tla, nothing, nothing)
Tracker(tla::SubString)::Tracker = Tracker(String(tla))

"""Returns an active session

If the tracker already has an active session then return it, otherwise create
one. The tracker specific modules should override this"""
ensure_login!(::Tracker{S}) where {S <: AbstractSession} =
    error("ensure_login! needs to be defined for Tracker{$S}")

ensure_login!(t::Tracker{StaticSession})::StaticSession =
    t.session = StaticSession()

Base.:(==)(t::Tracker, to::Tracker) =
    t.api == to.api && t.tla == to.tla &&
    t.host == to.host && t.scheme == t.scheme

function write_get_item_html_url(io::IO, tracker::Tracker, id::AbstractString)
    write(io, tracker.scheme, "://", tracker.host)
    render(io, tracker.api.get_item_html, :id => id)
end

"Tracker Repository"
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

load_trackers()::TrackerRepo = load_trackers(Conf.get_conf(:trackers))
function load_trackers(conf::Dict)::TrackerRepo
    tryget(api, thing) = haskey(api, thing) ? Template(api[thing]) : nothing

    apis = mapdic(conf["apis"]) do (name, api)
        name => Api{get_session_type(name)}(name, tryget(api, "get-item-html"))
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

include("Bugzilla.jl")
#include("Redmine.jl")
include("OpenQA.jl")

end #module
