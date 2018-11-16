module OpenQA

using Distributed
using JSON
using HTTP

using JDP.Repository
using JDP.Trackers
using JDP.BugRefs
using JDP.Conf

struct Session <: Trackers.AbstractSession
    url::String
end

o3 = Session("https://openqa.opensuse.org/api/v1")
osd = Session("http://openqa.suse.de/api/v1")

Trackers.ensure_login!(t::Tracker{Session}) = if t.session == nothing
    t.session = Session("$(t.scheme)://$(t.host)/api/v1")
else
    t.session
end

function get_json(host::Session, path::String)
    HTTP.get(joinpath(host.url, path), status_exception=true).body |>
        String |> JSON.parse
end

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
        sjob = ext -> save_job_json(host, jid, dir_path, i, N, ext)
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
                             jr::Dict{String, Any},
                             tr::Dict{String, Any},
                             tags::Tags)
    setts = jr["settings"]

    for dt in tr["details"]
        name = dt["title"]

        push!(res, TestResult(
            name,
            ["fstests", setts["XFSTESTS"]],
            "Unknown",
            setts["BUILD"],
            map_result_str(dt["result"]),
            setts["ARCH"],
            get_refs(tags, name)
        ))
    end
end

function get_test_results!(res::Vector{TestResult},
                           jr::Dict{String, Any},
                           tr::Dict{String, Any},
                           tags::Tags)
    setts = jr["settings"]

    if haskey(setts, "XFSTESTS") && tr["name"] == "1_"
        get_fstest_results!(res, jr, tr, tags)
        return
    end

    name = tr["name"]

    push!(res, TestResult(
        name,
        if haskey(setts, "LTP_COMMAND_FILE")
            ["LTP", setts["LTP_COMMAND_FILE"]]
        elseif haskey(setts, "XFSTESTS")
            ["fstests", setts["XFSTESTS"]]
        else
            ["OpenQA", get(tr, "category", missing)]
        end,
        "Unknown",
        setts["BUILD"],
        tr["result"],
        setts["ARCH"],
        get_refs(tags, name)
    ))
end

function parse_comments(comments::Array, trackers::TrackerRepo)::Tags
    tags = Tags()

    foreach(c -> extract_tags!(tags, c["text"], trackers), comments)

    tags
end

function Repository.retrieve(::TestResult, ::Vector, from::String;
                             refresh=false, kwargs...)::Vector{TestResult}
    datadir = Conf.data(:datadir)
    trackers = load_trackers()
    results = Vector{TestResult}()

    if refresh
        sess = Trackers.ensure_login!(get_tracker(trackers, from))
        save_job_results_json(sess, datadir; kwargs...)
    end

    json = load_job_results_json(datadir)

    for jr in json
        tags = parse_comments(jr["comments"], trackers)

        for tr in jr["testresults"]
            get_test_results!(results, jr, tr, tags)
        end
    end

    results
end

end # json
