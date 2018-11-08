module Trackers

export Api, Tracker, TrackerRepo, get_tracker, load_trackers

using Match

using JDP.Conf
using JDP.Templates

struct Api
    name::String
    get_bug_html::Union{Template, Nothing}
    get_bug_xml::Union{Template, Nothing}
end

Base.:(==)(a::Api, ao::Api) = a.name == ao.name

abstract type AbstractSession end

struct Tracker
    api::Union{Nothing, Api}
    session::Union{Nothing, AbstractSession}
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

function load_trackers()::TrackerRepo
    conf = Conf.get_conf(:trackers)

    tryget(api, thing) = haskey(api, thing) ? Template(api[thing]) : nothing

    apis = mapdic(conf["apis"]) do (name, api)
        name => Api(name, tryget(api, "get-bug-html"),
                          tryget(api, "get-bug-xml"))
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
