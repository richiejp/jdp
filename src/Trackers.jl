module Trackers

export Api, Tracker, TrackerRepo, get_tracker, load_trackers

using Match

using JDP.Conf

struct UrlVar
    name::String
end

const ApiUrl = Array{Union{String, UrlVar}, 1}

function ApiUrl(template::String)::ApiUrl
    url = ApiUrl()
    part = Char[]
    itr = iterate(url, 1)
    seen_bracket = false

    while itr != nothing
        @match (itr, seen_bracket) begin
            (('{', i), true) => throw("Found nested '{' at $i: $template")
            (('}', i), false) => throw("Found '}' without matching '{' at $i: $template")
            (('}' || '{', i), _) => begin
                if length(part) > 0
                    push!(url, seen_bracket ? UrlVar(String(part)) : String(part))
                    part = Char[]
                end

                seen_bracket = !seen_bracket
            end
            ((c, i), _) => push!(part, c)
        end

        itr = iterate(url, i)
    end

    if seen_bracket
        throw("Expected '}' found end of string: $template")
    elseif length(part) > 0
        push!(url, String(part))
    end

    url
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
            @match part begin
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
