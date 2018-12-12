module OpenQA

using Distributed
using JSON
using HTTP
import MbedTLS
import DataFrames: DataFrame
import JLD2: JLDFile, jldopen

using JDP.Repository
using JDP.Trackers
using JDP.BugRefs
using JDP.Conf
using JDP.IOHelpers

struct Session <: Trackers.AbstractSession
    url::String
    api::String
    ssl::MbedTLS.SSLConfig
end

Session(url::String) = Session(url, "api/v1", IOHelpers.sslconfig())

o3 = Session("https://openqa.opensuse.org")
osd = Session("https://openqa.suse.de")

Trackers.ensure_login!(t::Tracker{Session}) = if t.session == nothing
    t.session = Session("$(t.scheme)://$(t.host)")
else
    t.session
end

get_raw(host::Session, path::String; api::Bool=true) =
    HTTP.get(api ? joinpath(host.url, host.api, path) : joinpath(host.url, path),
             status_exception=true, sslconfig=host.ssl)

get_json(host::Session, path::String; api::Bool=true) =
    get_raw(host, path; api=api).body |> String |> JSON.parse

function get_machines(host::Session)
    get_json(host, "machines")["Machines"]
end

function get_group_jobs(host::Session, group_id::Int64)::Array{Int64}
    get_json(host, "job_groups/$group_id/jobs")["ids"]
end

function get_job_results(host::Session, job_id::Int64)
    get_json(host, "jobs/$job_id/details")["job"]
end

function get_jobs_overview(host::Session; kwargs...)
    uri = "jobs/overview"

    if length(kwargs) > 0
        uri *= "?"
    end

    for (k, v) in pairs(kwargs)
        uri *= "$k=$v&"
    end

    map(j -> j["id"], get_json(host, uri))
end

abstract type Item <: Repository.AbstractItem end
struct TestResult <: Item
    name::String
    suit::Vector{String}
    product::String
    build::String
    result::String
    arch::String
    refs::Vector{BugRefs.Ref}
end

TestResult()::TestResult = TestResult("", [], "", "", "", "", [])

struct TestStep
    name::String
    result::String
end

struct TestModule
    name::String
    result::String
    steps::Vector{TestStep}
end

struct Comment
    author::String
    created::String
    updated::String
    text::String
end

const VarsDict = Dict{String, Union{Int, String, Nothing}}

struct JobResult <: Item
    name::String
    id::Int
    state::String
    logs::Vector{String}
    vars::VarsDict
    result::String
    start::Union{String, Nothing}
    finish::Union{String, Nothing}
    modules::Vector{TestModule}
    comments::Vector{Comment}
end

const JsonDict = Dict{String,
                      Union{String, Int, Float64, Nothing, Dict, Vector}}

struct MappingException <: Exception
    jsonstack::Vector{Dict}
    root::Exception
end

function Base.show(io::IO, m::MIME"text/plain", e::MappingException)
    println(io, "Error while mapping JSON to object: ", e.root)
    for j in e.jsonstack
        show(IOContext(io, :limit => true), m, j)
        println(io, "\n")
    end
end
Base.show(io::IO, e::MappingException) = Base.show(io, MIME("text/plain"), e)

macro error_with_json(json, exp)
    quote
        try
            $(esc(exp))
        catch e
            rethrow(e isa MappingException ?
                    MappingException([e.jsonstack..., $(esc(json))], e.root) :
                    MappingException([$(esc(json))], e))
        end
    end
end

json_to_steps(details::Vector)::Vector{TestStep} = map(
    Iterators.filter(details) do d
        haskey(d, "title") && d["title"] != "wait_serial"
    end) do d
        @error_with_json(d, if d["title"] == "Soft Failed"
            TestStep(d["text_data"], "softfailed")
        else
            TestStep(d["title"], d["result"])
        end)
    end

json_to_modules(results::Vector)::Vector{TestModule} = map(results) do r
    @error_with_json(r, TestModule(r["name"],
                                   r["result"],
                                   json_to_steps(r["details"])))
end

function json_to_comments(comments::String)::Vector{Comment}
    j = JSON.parse(comments; dicttype=JsonDict)

    map(j) do c
        @error_with_json(c, Comment(c["userName"],
                                    c["created"],
                                    c["updated"],
                                    c["text"]))
    end
end

function json_to_job(job::String; vars::String="", comments::String="")::JobResult
    j = JSON.parse(job; dicttype=JsonDict)["job"]

    @error_with_json(j,
        JobResult(
            j["name"],
            j["id"],
            j["state"],
            vcat(j["logs"], j["ulogs"]),
            isempty(vars) ? j["settings"] : JSON.parse(vars; dicttype=VarsDict),
            j["result"],
            j["t_started"],
            j["t_finished"],
            json_to_modules(j["testresults"]),
            isempty(comments) ? Comment[] : json_to_comments(comments)))
end

function load_job_results(jldf::JLDFile)::Vector{JobResult}
    map(Iterators.filter(keys(jldf)) do k
        startswith(k, "job")
    end) do k
        read(jldf, k)
    end
end

function flatten(arr::Array)
    map(flatten, arr)
end

function flatten(dict::Dict{String, Any})
    dc = copy(dict)
    delete!(dc, "settings")
    setts::Dict{String, Any} = Dict()
    for s in dict["settings"]
        setts[s["key"]] = s["value"]
    end
    dc["settings"] = setts
    dc
end

"""
    load_job_results_json(directory_path)

Load the job details and comment JSON files into Julia dictionarys and array
objects.

"""
function load_job_results_json(dir_path::String)
    dir_path = realpath(dir_path)

    names = filter!(name -> endswith(name, "job-details.json"), readdir(dir_path))
    map!(name -> joinpath(dir_path, name), names, names)
    filter!(isfile, names)
    
    pmap(names; batch_size=2) do file_path
        js = JSON.parsefile(file_path)["job"]
        cfile = joinpath(dir_path, "$(js["id"])-job-comments.json")

        if isfile(cfile)
            js["comments"] = JSON.parsefile(cfile, use_mmap=true)
            if length(js["comments"]) < 1
                rm(cfile)
            end
        else
            js["comments"] = []
        end

        js
    end
end

function load_job_results_json(dir_paths::Array{String})::Array
    results = []

    for dir in dir_paths
        append!(results, load_job_results_json!(dir, results))
    end

    results
end

function save_job_json(host::Session,
                       jid::Integer,
                       dir_path::String,
                       i::Integer, N::Integer;
                       ext::String="", overwrite::Bool=false)
    url = joinpath(host.url, "jobs", "$jid", ext)
    file = joinpath(dir_path, "$jid-job-$ext.json")
    if overwrite || !isfile(file)
        @info "$i/$N GET $url"
        req = HTTP.get(url, status_exception = true)
        @info "$i/$N WRITE $file"
        open(f -> write(f, req.body), file, "w")
    else
        @debug "$i/$N SKIP $url"
    end
end

function save_job_results_json(host::Session, dir_path::String; kwargs...)
    dir_path = realpath(dir_path)
    if !isdir(dir_path)
        throw("Not a directory $dir_path")
    end

    jgrps = get_jobs_overview(host; kwargs...)
    i = 1
    N = length(jgrps)
    for jid in jgrps
        sjob = ext -> save_job_json(host, jid, dir_path, i, N, ext=ext)
        sjob("details")
        sjob("comments")
        i += 1
    end
end

function save_job_comments_json(host::Session, dir_path::String; kwargs...)
    dir_path = realpath(dir_path)
    if !isdir(dir_path)
        throw("Not a directory $dir_path")
    end

    jgrps = get_jobs_overview(host; kwargs...)
    i = 1
    N = length(jgrps)
    for jid in jgrps
        save_job_json(host, jid, dir_path, i, N, "comments"; overwrite=true)
        i += 1
    end
end

function map_result_str(res::String)::String
    if res === "ok"
        "passed"
    elseif res === "fail"
        "failed"
    else
        "none"
    end
end

function get_fstest_results!(res::Vector{TestResult},
                             jr::JobResult,
                             m::TestModule,
                             tags::Tags)
    var = jr.vars

    for dt in m.details
        push!(res, TestResult(
            dt.name,
            ["fstests", var["XFSTESTS"]],
            get(var, "PRODUCT", "Unknown"),
            var["BUILD"],
            map_result_str(dt.result),
            var["ARCH"],
            get_refs(tags, dt.name)
        ))
    end
end

function get_test_results!(res::Vector{TestResult},
                           jr::JobResult,
                           m::TestModule,
                           tags::Tags)
    var = jr.vars

    if haskey(var, "XFSTESTS") && m.name == "1_"
        get_fstest_results!(res, jr, m, tags)
        return
    end

    push!(res, TestResult(
        m.name,
        if haskey(var, "LTP_COMMAND_FILE")
            ["LTP", var["LTP_COMMAND_FILE"]]
        elseif haskey(var, "XFSTESTS")
            ["fstests", var["XFSTESTS"]]
        else
            ["OpenQA"]
        end,
        get(var, "PRODUCT", "Unknown"),
        var["BUILD"],
        m.result,
        var["ARCH"],
        get_refs(tags, m.name)
    ))
end

function parse_comments(comments::Vector{Comment}, trackers::TrackerRepo)::Tags
    tags = Tags()

    for c in comments
        extract_tags!(tags, c.text, trackers)
    end

    tags
end

function Repository.fetch(::Type{TestResult}, ::Type{Vector}, from::String;
                             refresh=false, kwargs...)::Vector{TestResult}
    datadir = Conf.data(:datadir)
    trackers = load_trackers()
    results = Vector{TestResult}()

    if refresh
        # not implemented
    end

    jldf = jldopen(joinpath(datadir, "$from.jld2"), true, false, false)

    for jr in load_job_results(jldf)
        tags = parse_comments(jr.comments, trackers)

        for m in jr.modules
            get_test_results!(results, jr, m, tags)
        end
    end

    results
end

function Repository.fetch(::Type{TestResult}, ::Type{DataFrame}, from::String;
                             refresh=false, kwargs...)::DataFrame
    results = Repository.fetch(TestResult, Vector, from; refresh=refresh, kwargs...)

    cols::Array{Any} = [String[]]
    push!(cols, Vector{String}[])
    append!(cols, [String[] for _ in 1:4])
    push!(cols, Vector{BugRefs.Ref}[])

    for r in results
        push!(cols[1], r.name)
        push!(cols[2], r.suit)
        push!(cols[3], r.product)
        push!(cols[4], r.build)
        push!(cols[5], r.result)
        push!(cols[6], r.arch)
        push!(cols[7], r.refs)
    end

    DataFrame(cols, [:name, :suit, :product, :build, :result, :arch, :refs])
end

end # json
