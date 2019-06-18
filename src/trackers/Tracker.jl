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
module Tracker

export Api, TrackerRepo, get_tracker, load_trackers

# Tracker specific modules are appended to this module in JDP.jl

import JDP
using JDP.Conf
using JDP.Lazy
using JDP.Templates

"""A connection to a tracker API

Each Tracker which supports the concept of logging in should create a struct
like the following

```julia
struct Session <: Tracker.AbstractSession
    # Tracker specific session data...
end
```

and also implement [`ensure_login!`](@ref)

!!! warn

    This module looks for a struct specifically called `Session` when
    automatically loading the trackers. So the name is significant.

"""
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

Base.hash(a::Api, h::UInt) = hash(a.name, h)

"Information about a Tracker's instance"
mutable struct Instance{S <: AbstractSession}
    api::Union{Nothing, Api{S}}
    session::Union{Nothing, S}
    tla::String
    scheme::Union{Nothing, String}
    host::Union{Nothing, String}
end

"Create a minimal tracker instance for an unknown tracker"
Instance(tla::String) =
    Instance{StaticSession}(nothing, nothing, tla, nothing, nothing)
Instance(tla::SubString)::Instance = Instance(String(tla))

struct InstanceLink <: Lazy.AbstractLink
    tla::String
end

Base.:(==)(r::InstanceLink, l::InstanceLink) = r.tla == l.tla
Base.hash(l::InstanceLink, h::UInt) = hash(l.tla, h)

"""Returns an active session

If the tracker already has an active session then return it, otherwise create
one. The tracker specific modules should override this"""
ensure_login!(::Instance{S}) where {S <: AbstractSession} =
    error("ensure_login! needs to be defined for Instance{$S}")

ensure_login!(t::Instance{StaticSession})::StaticSession =
    t.session = StaticSession()

"Get an active session object for the tracker with the given TLA"
login(tla::AbstractString)::AbstractSession =
    ensure_login!(get_tracker(tla))

Base.:(==)(t::Instance, to::Instance) =
    t.api == to.api && t.tla == to.tla &&
    t.host == to.host

Base.hash(t::Instance, h::UInt) = hash(t.api, hash(t.tla, hash(t.host, h)))

function write_get_item_html_url(io::IO, tracker::Instance, id::AbstractString)
    write(io, tracker.scheme, "://", tracker.host)
    render(io, tracker.api.get_item_html, :id => id)
end

"Tracker Repository"
struct TrackerRepo
    apis::Dict{String, Api}
    instances::Dict{String, Instance}
end

get_tracker(repo::TrackerRepo, tla::AbstractString)::Instance = get(repo.instances, tla) do
    @warn "Unknown tracker identifier (TLA) `$tla`"
    Instance(tla)
end
Lazy.load(repo::TrackerRepo, link::InstanceLink) = get_tracker(repo, link.tla)

"Get a single tracker from its TLA"
get_tracker(tla::AbstractString)::Instance = get_tracker(load_trackers(), tla)
Lazy.load(link::InstanceLink) = get_tracker(link.tla)

mapdic(fn, m) = map(fn, zip(keys(m), values(m))) |> Dict

get_session_type(::Nothing) = StaticSession
get_session_type(tracker::String) = try
    tmod = getproperty(JDP.Trackers, Symbol(tracker))
    getproperty(tmod, :Session)
catch e
    @debug "No tracker session type for `$tracker`; inner exception: \n$e"
    StaticSession
end

"Get a collection of all Trackers"
load_trackers()::TrackerRepo = load_trackers(Conf.get_conf(:trackers))
load_trackers(conf::Dict)::TrackerRepo = begin
    tryget(api, thing) = haskey(api, thing) ? Template(api[thing]) : nothing

    apis = mapdic(conf["apis"]) do (name, api)
        name => Api{get_session_type(name)}(name, tryget(api, "get-item-html"))
    end

    insts = mapdic(conf["instances"]) do (name, inst)
        api = get(inst, "api", nothing)

        name => Instance{get_session_type(api)}(
            get(apis, api, nothing),
            nothing,
            get(inst, "tla", name),
            get(inst, "scheme", haskey(inst, "host") ? "https" : nothing),
            get(inst, "host", nothing))
    end

    TrackerRepo(apis, insts)
end

function get_bug_type(tracker::Instance{S})::Union{Nothing, Type} where {S}
    try
        tmod = parentmodule(S)
        getproperty(tmod, :Bug)
    catch exception
        @debug "Could not get Tracker's bug type" tracker exception
    end
end

end #module
