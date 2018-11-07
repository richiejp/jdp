module Trackers

export Api, Tracker, TrackerRepo, get_tracker, load_trackers, @api_str

using Match

using JDP.Conf

struct OpenBracketError <: Exception msg::String end
struct CloseBracketError <: Exception msg::String end
struct EOSError <: Exception msg::String end

struct UrlVar
    name::String
end

Base.:(==)(u::UrlVar, uo::UrlVar) = u.name == uo.name

const ApiUrl = Array{Union{String, UrlVar}, 1}

function ApiUrl(template::String)::ApiUrl
    url = ApiUrl()
    part = IOBuffer()
    seen_bracket = false

    for (i::Int, c::Char) in enumerate(template)
        if c == '{' && seen_bracket
            throw(OpenBracketError("Found nested '{' at $i: $template"))
        elseif c == '}' && !seen_bracket
            throw(CloseBracketError("Found '}' without matching '{' at $i: $template"))
        elseif c == '{' || c == '}'
            if part.size > 0
                s = String(take!(part))
                push!(url, seen_bracket ? UrlVar(s) : s)
            end

            seen_bracket = !seen_bracket
        else
            write(part, c)
        end
    end

    if seen_bracket
        throw(EOSError("Expected '}' found end of string: $template"))
    elseif part.size > 0
        push!(url, String(take!(part)))
    end

    url
end

macro api_str(template)
    ApiUrl(template)
end

struct Api
    name::String
    get_bug_html::Union{ApiUrl, Nothing}
    get_bug_xml::Union{ApiUrl, Nothing}
end

Base.:(==)(a::Api, ao::Api) = a.name == ao.name

struct Tracker
    api::Union{Nothing, Api}
    tla::String
    host::Union{Nothing, String}
end

Base.:(==)(t::Tracker, to::Tracker) =
    t.api == to.api && t.tla == to.tla && t.host == to.host

function write_get_bug_html_url(io::IO, tracker::Tracker, id::AbstractString)
    for part in tracker.api.get_bug_html
        if part isa UrlVar
            @match part.name begin
                "host" => write(io, tracker.host)
                "id" => write(io, id)
                _ => throw("Unknown Tracker.UrlVar: $part")
            end
        else
            write(io, part)
        end
    end
end

struct TrackerRepo
    apis::Dict{String, Api}
    instances::Dict{String, Tracker}
end

get_tracker(repo::TrackerRepo, tla::AbstractString)::Tracker = get(repo.instances, tla) do
    Tracker(nothing, tla, nothing)
end

mapdic(fn, m) = map(fn, zip(keys(m), values(m))) |> Dict

function load_trackers()::TrackerRepo
    conf = Conf.get_conf(:trackers)

    tryget(api, thing) = haskey(api, thing) ? ApiUrl(api[thing]) : nothing

    apis = mapdic(conf["apis"]) do (name, api)
        name => Api(name, tryget(api, "get-bug-html"),
                          tryget(api, "get-bug-xml"))
    end

    insts = mapdic(conf["instances"]) do (name, inst)
        name => Tracker(get(apis, get(inst, "api", nothing), nothing),
                        get(inst, "tla", name),
                        get(inst, "host", nothing))
    end

    TrackerRepo(apis, insts)
end

end #module
