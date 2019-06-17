module OpenQA

using Distributed
using JSON
using HTTP
import Dates: now, Date, Month, Week, Year
import MbedTLS
import DataFrames: DataFrame
import DataStructures: SortedSet, SortedDict
import TOML

import JDP.Functional: cifilter, cmap, cimap, cforeach
using JDP.Templates
using JDP.Lazy
using JDP.Repository
using JDP.Tracker
using JDP.BugRefs
using JDP.Conf
using JDP.IOHelpers

abstract type AbstractSession <: Tracker.AbstractSession end

"""Use native Julia HTTP library to access OpenQA

Unfortunately this doesn't work so well because:

1. JuliaWeb's current HTTP SSL implementation i.e. the MbedTLS wrapper
2. OpenQA's wierd authentication which is difficult to replicate outside of
   Perl.
"""
struct NativeSession <: AbstractSession
    url::String
    api::String
    ssl::MbedTLS.SSLConfig
end
NativeSession(url::String) = NativeSession(url, "api/v1", IOHelpers.sslconfig())

Tracker.ensure_login!(t::Tracker.Instance{NativeSession}) = if t.session == nothing
    t.session = NativeSession("$(t.scheme)://$(t.host)")
else
    t.session
end

get_raw(host::NativeSession, path::String; api::Bool=true) =
    HTTP.get(api ? joinpath(host.url, host.api, path) : joinpath(host.url, path),
             status_exception=true, sslconfig=host.ssl)

get_json(host::NativeSession, path::String; api::Bool=true) =
    get_raw(host, path; api=api).body |> String |>
    JSON.parse(;dicttype=JsonDict)

"""Makes requests to OpenQA using the official OpenQA client script

I really hate this, but we cache the data locally anyway due to the slowness
of fetching from OpenQA, so the overhead of calling a Perl script can be
ignored. Also see OpenQA::NativeSession's docs."""
struct Session <: AbstractSession
    host::String
    cmd::Cmd
    apikey::String
    apisecret::String
end

Session(host::String, key::String, secret::String) =
    Session(host, `openqa-client --json-output --host`, key, secret)

Session(host::String) = Session(host, "1234567890ABCDEF", "1234567890ABCDEF")

Tracker.ensure_login!(t::Tracker.Instance{Session}) = if t.session == nothing
    conf = Conf.get_conf(:trackers)["instances"]
    if !haskey(conf, t.tla)
        @warn "No host definition in trackers.toml for $(t.host)"
        return t.session = Session(t.host)
    end

    host = conf[t.tla]
    if haskey(host, "apikey") && haskey(host, "apisecret")
        return t.session = Session(t.host, host["apikey"], host["apisecret"])
    end
    t.session = Session(t.host)
else
    t.session
end

get_raw(ses::Session, path::String; api::Bool=true) = if api
    read(`$(ses.cmd) $(ses.host) $path`, String)
else
    read(`$(ses.cmd) $(ses.host) --apibase / $path`, String)
end

get_json(host::Session, path::String; api::Bool=true) =
    JSON.parse(get_raw(host, path; api=api); dicttype=JsonDict)

get_json(path::String, from::String; api::Bool=true) =
    get_json(Tracker.ensure_login!(get_tracker(load_trackers(), from)),
             path; api=api)

post_raw(ses::Session, path::String, post::String) = read(
    `$(ses.cmd) $(ses.host) --apikey $(ses.apikey) --apisecret $(ses.apisecret) $path post $post`,
    String)

post_json(ses::Session, path::String, post::String) =
    JSON.parse(post_raw(ses, path, post); dicttype=JsonDict)

delete_json(ses::Session, path::String) = JSON.parse(read(
    `$(ses.cmd) $(ses.host) --apikey $(ses.apikey) --apisecret $(ses.apisecret) $path delete`,
    String); dicttype=JsonDict)

o3 = Session("openqa.opensuse.org")
no3 = NativeSession("https://openqa.opensuse.org")
osd = Session("openqa.suse.de")
nosd = NativeSession("https://openqa.suse.de")

get_job_vars(host::AbstractSession, job_id::Int64)::Union{VarsDict, Nothing} = try
    path = "tests/$job_id/file/vars.json"
    JSON.parse(get_raw(host, path; api=false); dicttype=VarsDict)
catch e
    @debug "GET $path: $(e.msg)"
    nothing
end

get_job_comments(host::AbstractSession, job_id::Int64)::Vector{JsonDict} =
    get_json(host, "jobs/$job_id/comments")

get_machines(host::AbstractSession) = get_json(host, "machines")["Machines"]

get_job_group_parent_json(host::AbstractSession, id::Int64) =
    get_json(host, "parent_groups/$id")[1]

get_job_group_json(host::AbstractSession, id::Int64) =
    get_json(host, "job_groups/$id")[1]

get_job_groups_json(host::AbstractSession) =
    get_json(host, "job_groups")

function get_group_jobs(host::AbstractSession, group_id::Int64)::Array{Int64}
    get_json(host, "job_groups/$group_id/jobs")["ids"]
end

function get_job_results(host::AbstractSession, job_id::Int64)
    get_json(host, "jobs/$job_id/details")["job"]
end

function get_jobs_overview(host::AbstractSession; kwargs...)
    uri = "jobs/overview"

    if length(kwargs) > 0
        uri *= "?"
    end

    for (k, v) in pairs(kwargs)
        uri *= "$k=$v&"
    end

    map(j -> j["id"], get_json(host, uri))
end

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
    id::Int64
    author::String
    created::String
    updated::String
    text::String
end

const VarsDict = Dict{String, Union{Int64, String, Nothing}}

abstract type Item <: Repository.AbstractItem end

struct Link{T} <: Lazy.AbstractLink where {T <: Item}
    host::Tracker.InstanceLink
    id::Int64
end

Link{T}(tla::String, id) where T = Link{T}(Tracker.InstanceLink(tla), id)

Base.:(==)(r::Link, l::Link) = false
Base.:(==)(r::Link{T}, l::Link{T}) where T =
    r.host == l.host && r.id == l.id

abstract type AbstractJobGroup <: Item end

struct JobGroupParent <: AbstractJobGroup
    id::Int64
    parent::Union{Link{JobGroupParent}, Tracker.InstanceLink}
    name::String
    description::String
end

struct JobGroup <: AbstractJobGroup
    id::Int64
    parent::Union{Link{JobGroupParent}, Tracker.InstanceLink}
    name::String
    description::String
end

mutable struct JobResult <: Item
    name::String
    id::Int64
    group::Link{JobGroup}
    state::String
    logs::Vector{String}
    vars::VarsDict
    result::String
    start::Union{String, Nothing}
    finish::Union{String, Nothing}
    modules::Vector{TestModule}
    comments::Vector{Comment}
end

struct JobResultSetDef
    name::String
    creator::Function
end

struct JobResultSet <: Item
    def::JobResultSetDef
    ids::Vector{Int64}
end

const TestFlags = SortedSet{String}

function Base.isless(r::TestFlags, l::TestFlags)
    for (rf, lf) in zip(r, l)
        rf < lf && return true
        rf ≠ lf && return false
    end
    length(r) < length(l)
end

Base.isequal(r::TestFlags, l::TestFlags) =
    length(r) == length(l) &&
    all(t -> isequal(t...), zip(r, l))

Base.:(==)(r::TestFlags, l::TestFlags) = isequal(r, l)

struct TestResult <: Item
    name::String
    suit::Vector{String}
    product::String
    build::String
    result::String
    arch::String
    machine::String
    refs::Vector{BugRefs.Ref}
    job::JobResult
    flags::TestFlags
end

start_date(job::JobResult)::Union{Nothing, Date} =
    job.start ≠ nothing ? Date(job.start[1:10], "yyyy-mm-dd") : nothing

get_fqn(tr::TestResult)::String = join(vcat(tr.suit, tr.name), ":")

Base.show(io::IO, ::MIME"text/markdown", tr::TestResult) =
    print(io, "[", get_fqn(tr), "](https://openqa.suse.de/tests/", tr.job.id,
          "#step/", tr.name, "/1) @ `", tr.job.name, "`")

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

json_to_job_group_parent(tla::String, g::AbstractDict)::JobGroup =
    JobGroup(g["id"], Tracker.InstanceLink(tla), g["name"],
             g["description"] == nothing ? "" : g["description"])

json_to_job_group(tla::String, g::AbstractDict)::JobGroup =
    JobGroup(g["id"],
             if g["parent_id"] == nothing
                 Tracker.InstanceLink(tla)
             else
                 Link{JobGroupParent}(tla, g["parent_id"])
             end,
             g["name"],
             g["description"] == nothing ? "" : g["description"])

json_to_job_groups(tla::String, gs::AbstractVector)::Vector{JobGroup} =
    [json_to_job_group(tla, g) for g in gs]

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

json_to_comments(comments::String)::Vector{Comment} =
    convert(Vector{JsonDict},
            JSON.parse(comments; dicttype=JsonDict)) |> json_to_comments

json_to_comments(comments::Vector{JsonDict})::Vector{Comment} = map(comments) do c
    @error_with_json(c, Comment(c["id"],
                                c["userName"],
                                c["created"],
                                c["updated"],
                                c["text"]))
end

function json_to_job(tla::String, job::String; vars::String="", comments::String="")::JobResult
    json_to_job(tla, JSON.parse(job; dicttype=JsonDict)["job"];
                vars=vars == "" ? nothing : JSON.parse(vars; dicttype=VarsDict),
                comments=comments == "" ? nothing : json_to_comments(comments))
end

function json_to_job(tla::String, job::JsonDict;
                     vars::Union{VarsDict, Nothing}=nothing,
                     comments::Union{Vector{Comment}, Nothing}=nothing)::JobResult
    j = job
    @error_with_json(job,
        JobResult(
            j["name"],
            j["id"],
            Link{JobGroup}(tla, j["group_id"]),
            j["state"],
            vcat(j["logs"], j["ulogs"]),
            vars == nothing ? j["settings"] : vars,
            j["result"],
            j["t_started"],
            j["t_finished"],
            json_to_modules(j["testresults"]),
            comments == nothing ? Comment[] : comments))
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

function get_job_group_parent(host::Tracker.Instance, id::Int64)::JobGroupParent
    ses = Tracker.ensure_login!(host)
    json = get_job_group_parent_json(ses, id)
    json_to_job_group_parent(host.tla, json)
end

function get_job_group(host::Tracker.Instance, id::Int64)::JobGroup
    ses = Tracker.ensure_login!(host)
    json = get_job_group_json(ses, id)
    json_to_job_group(host.tla, json)
end

function get_job_groups(host::Tracker.Instance)::Vector{JobGroup}
    ses = Tracker.ensure_login!(host)
    json = get_job_groups_json(ses)
    json_to_job_groups(host.tla, json)
end

function save_job_results_json(host::AbstractSession, dir_path::String; kwargs...)
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

function save_job_comments_json(host::AbstractSession, dir_path::String; kwargs...)
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

post_job_comment(host::AbstractSession, job::Int, text::String) =
    post_json(host, "jobs/$job/comments", "text=$text")

delete_job_comment(host::AbstractSession, job::Int, comment::Int)::Int =
    delete_json(host, "jobs/$job/comments/$comment")["id"]

const step_to_module_result =
    Dict("ok" => "passed", "unk" => "none", "fail" => "failed",
         "skip" => "skipped", "missing" => "skipped")
function map_result_str(res::String)::String
    get(step_to_module_result, res, res)
end

function get_product(vars::VarsDict)::String
    if haskey(vars, "DISTRI")
        join([vars["DISTRI"],
              get(vars, "VERSION", "unknown"),
              get(vars, "FLAVOR", "unknown")], "-")
    else
        "unknown"
    end
end

function get_fstest_results!(res::Vector{TestResult},
                             jr::JobResult,
                             m::TestModule,
                             tags::Tags)
    var = jr.vars

    for step in m.steps
        push!(res, TestResult(
            step.name,
            ["fstests", var["XFSTESTS"]],
            get_product(var),
            var["BUILD"],
            map_result_str(step.result),
            var["ARCH"],
            var["MACHINE"],
            get_refs(tags, step.name),
            jr,
            TestFlags()
        ))
    end
end

function get_test_results!(res::Vector{TestResult},
                           jr::JobResult,
                           m::TestModule,
                           tags::Tags)
    var = jr.vars

    if haskey(var, "XFSTESTS") && startswith(m.name, "1_")
        get_fstest_results!(res, jr, m, tags)
        return
    end

    flags = TestFlags()
    push_flag!(flag::String, cond::Bool) = if cond
        push!(flags, flag)
    end
    push_flag!("m32", endswith(var["TEST"], "m32"))
    push_flag!("Public Cloud", haskey(var, "PUBLIC_CLOUD"))

    push!(res, TestResult(
        m.name,
        if haskey(var, "LTP_COMMAND_FILE")
            ["LTP", var["LTP_COMMAND_FILE"]]
        elseif haskey(var, "PUBLIC_CLOUD_LTP") && haskey(var, "COMMAND_FILE")
            ["LTP", var["COMMAND_FILE"]]
        elseif haskey(var, "PUBLIC_CLOUD_IPA_TESTS") || haskey(var, "PUBLIC_CLOUD_CHECK_BOOT_TIME")
            ["IPA"]
        elseif haskey(var, "XFSTESTS")
            ["fstests", var["XFSTESTS"]]
        elseif haskey(var, "HPC")
            ["OpenQA", "HPC", var["HPC"]]
        else
            ["OpenQA"]
        end,
        get_product(var),
        var["BUILD"],
        m.result,
        var["ARCH"],
        var["MACHINE"],
        get_refs(tags, m.name),
        jr,
        flags
    ))
end

function parse_comments(comments::Vector{Comment},
                        trackers::TrackerRepo)::Tags
    tags = Tags()

    for c in comments
        if !occursin(r"\(Automatic takeover from t#\d+\)", c.text)
            extract_tags!(tags, c.text, trackers)
        end
    end

    tags
end

Repository.fetch(T::Type{JobResult}, ::Type{Vector}, from::String) =
    Repository.mload("$from-job-[0-9]*", T)

Repository.fetch(T::Type{JobResult}, ::Type{Vector}, from::String, ids) =
    Repository.mload(("$from-job-$id" for id in ids), T)

Repository.fetch(T::Type{JobResult}, V::Type{Vector}, from::String, def::JobResultSetDef) =
    Repository.fetch(T, V, from, Repository.fetch(def, from).ids)

function Repository.fetch(T::Type{JobGroupParent}, from::String, id)::JobGroupParent
    g = Repository.load("$from-job-group-parent-$id", T)
    g ≠ nothing && return g

    g = get_job_group_parent(Tracker.get_tracker(from), id)
    Repository.store("$from-job-group-parent-$id", g)
    g
end

function Repository.fetch(T::Type{JobGroup}, from::String, id)::JobGroup
    g = Repository.load("$from-job-group-$id", T)
    g ≠ nothing && return g

    g = get_job_group(Tracker.get_tracker(from), id)
    Repository.store("$from-job-group-$id", g)
    g
end

Repository.fetch(T::Type{JobGroup}, ::Type{Vector}, from::String) =
    Repository.mload("$from-job-group-*", T)

function Repository.refresh(def::JobResultSetDef, from::String)::JobResultSet
    jrs = Repository.fetch(JobResult, Vector, from)
    s = JobResultSet(def, def.creator(jrs)::Vector{Int64})

    Repository.store("$from-jobset-$(def.name)", s) || @error "Did not save" def.name
    s
end

function Repository.fetch(def::JobResultSetDef, from::String)::JobResultSet
    set = Repository.load("$from-jobset-$(def.name)", JobResultSet)
    set ≠ nothing && return set

    Repository.refresh(def, from)
end

function Lazy.load(link::Link{T})::T where T <: Item
    Repository.fetch(T, link.host.tla, link.id)
end

function refresh_comments(pred::Function, from::String)
    trackers = load_trackers()
    tracker = get_tracker(trackers, from)

    @info "Loading existing jobs"
    all = Repository.fetch(JobResult, Vector, from)
    jrs = filter(pred, all)

    @info "Refreshing comments on $(length(jrs)) jobs"
    for (i, job) in enumerate(jrs)
        @info "GET job $i/$(length(jrs))"
        ses = Tracker.ensure_login!(tracker)
        comments = try
            json_to_comments(get_job_comments(ses, job.id))
        catch
            nothing
        end
        if comments != nothing
            job.comments = comments
            Repository.store("$from-job-$(job.id)", job)
        end
    end
end

get_first_job_after_date(jobs, date) =
        Iterators.filter(job -> job.start != nothing, jobs) |>
        map[job -> job => start_date(job)] |>
        filter[jp -> jp[2] > date] |>
        (jobs -> sort(jobs; by=jp->jp[1].id)) |> first |> first

function refresh!(tracker::Tracker.Instance{S}, group::JobGroup,
                 jrs::Dict{String, JobResult}) where {S <: AbstractSession}
    ses = Tracker.ensure_login!(tracker)
    jids = @async get_group_jobs(ses, group.id)

    jids = if isempty(jrs)
        jids = fetch(jids)
        min_id = maximum(jids) - 20_000
        filter(id -> id > min_id, jids)
    else
        min_id = get_first_job_after_date(values(jrs), Date(now()) - Month(1)).id

        fjindx = BitSet(j.id for j in values(jrs)
                        if occursin(r"^(skipped|cancelled|done)$", j.state))
        filter(jid -> jid >= min_id && !(jid in fjindx), fetch(jids))
    end
    jobn = length(jids)

    @info "Refreshing $jobn jobs from the $(group.name) group ($(group.id))"
    jids |> enumerate |> cimap() do (indx, jid)
        @info "GET job $jid ($indx of $jobn)"
        res = @async get_job_results(ses, jid)
        coms = @async get_job_comments(ses, jid) |> json_to_comments
        vars = @async get_job_vars(ses, jid)
        json_to_job(tracker.tla, fetch(res); vars=fetch(vars), comments=fetch(coms))
    end |> cforeach() do job
        k = "$(tracker.tla)-job-$(job.id)"
        Repository.store(k, job)
        jrs[k] = job
    end
end

function Repository.refresh(tracker::Tracker.Instance{S},
                            groups::Vector{JobGroup}) where {S <: AbstractSession}
    jrs = Dict("$(tracker.tla)-job-$(job.id)" => job for
               job in Repository.fetch(JobResult, Vector, tracker.tla))

    for group in groups
        refresh!(tracker, group, jrs)
    end
end

function Repository.refresh(tracker::Tracker.Instance{S},
                            group::JobGroup) where {S <: AbstractSession}
    Repository.refresh(tracker, [group])
end

function Repository.refresh(tracker::Tracker.Instance{S},
                            ::Type{JobGroup}) where {S <: AbstractSession}

    groups = get_job_groups(tracker)

    for group in groups
        Repository.store("$(tracker.tla)-job-group-$(group.id)", group)
    end

    groups
end

function jobs_to_tests!(jrs::Vector{JobResult}, from::String)::Vector{TestResult}
    trackers = load_trackers()
    tracker = get_tracker(trackers, from)
    results = Vector{TestResult}()

    for jr in jrs
        tags = parse_comments(jr.comments, trackers)

        for m in jr.modules
            get_test_results!(results, jr, m, tags)
        end
    end

    results
end

Repository.fetch(::Type{TestResult}, ::Type{Vector}, from::String, ids)::Vector{TestResult} =
    jobs_to_tests!(Repository.fetch(JobResult, Vector, from, ids), from)

Repository.fetch(::Type{TestResult}, ::Type{Vector}, from::String)::Vector{TestResult} =
    jobs_to_tests!(Repository.fetch(JobResult, Vector, from), from)

function tests_to_dataframe(results::Vector{TestResult})::DataFrame
    cols::Array{Any} = [String[]]
    push!(cols, Vector{String}[])
    append!(cols, [String[] for _ in 1:5])
    push!(cols, Vector{BugRefs.Ref}[])
    push!(cols, Vector{String}[])

    for r in results
        push!(cols[1], r.name)
        push!(cols[2], r.suit)
        push!(cols[3], r.product)
        push!(cols[4], r.build)
        push!(cols[5], r.result)
        push!(cols[6], r.arch)
        push!(cols[7], r.machine)
        push!(cols[8], r.refs)
        push!(cols[9], [r.flags...])
    end

    DataFrame(cols, [:name, :suit, :product, :build, :result, :arch, :machine, :refs, :flags])
end

Repository.fetch(::Type{TestResult}, ::Type{DataFrame}, from::String, ids)::DataFrame =
    tests_to_dataframe(Repository.fetch(TestResult, Vector, from, ids))

Repository.fetch(::Type{TestResult}, ::Type{DataFrame}, from::String)::DataFrame =
    tests_to_dataframe(Repository.fetch(TestResult, Vector, from))

"""
    dict = extract_toml("text... <code data-type='TOML'>[JDP.some.toml]<br> ... </code>")

Find the first instance of toml contained inside some text formatted for
OpenQA job comments or group descriptions.

Only toml inside a the first code tag will be parsed. Code tags which don't
have a `data-type` of TOML will be ignored. The `<br>` tags just effect the
appearance in OpenQA. You should include them to make it readable.

"""
function extract_toml(text::AbstractString)::Union{Nothing, AbstractDict}
    m = match(r"<code data-type=[\"']TOML[\"']>(.*)</code>"s, text)
    m == nothing && return nothing

    toml = replace(m[1], "<br>" => "")
    parser = TOML.Parser(toml)
    config = TOML.parse(parser)
    if config == nothing
        @error "Parsing TOML" parser.error toml
    end

    TOML.table2dict(config)
end

"""
    test_prefs = load_notify_preferences(from::String, invert=true)::Dict{String, Vector{String}}

This loads and parses TOML formatted user notification preferences stored in
the OpenQA job group descriptions. Each user can set one or more patterns
which are matched against test suit, test name, test flags and maybe more to
determine if they should be sent a notification regarding some test.

### Arguments

- `from`: This is the TLA of the tracker (e.g. "osd") where the
          description text should be loaded from.
- `invert`: Whether to invert the mapping from user -> tests to test -> users.
            Default is `true`

### OpenQA Input

The raw OpenQA job group description text should contain something like the
following.

```toml
<code data-type='TOML'>
[JDP.notify.on-status-diff] <br>
rpalethorpe = ['LTP', 'OpenQA'] <br>
metan = 'LTP' <br>
pvorel = 'LTP' <br>
mmoese = ['nvmftests', 'LTP'] <br>
lansuse = 'fstests' <br>
yosun = 'fstests' <br>
cfconrad = 'udev.no-partlabel-links' <br>
</code>
```

For each user name you can set a single string or a vector of strings. These
are then passed to `occursin` as plain strings or maybe regexes depending on
the report.

### Returns

This returns a Dictionary mapping each pattern string to a vector of
users. Unless `invert=false` in which case the resulting dictionary matches
the TOML except that single strings are wrapped in a vector.

"""
function load_notify_preferences(from::String, invert=true)::Dict{String, Vector{String}}
    jgroups = Repository.fetch(OpenQA.JobGroup, Vector, "osd")
    [jgroup.id => jgroup.name for jgroup in jgroups]

    userprefs = Dict{String, Set{String}}()
    for jgroup in jgroups
        config = extract_toml(jgroup.description)
        if config ≠ nothing && (haskey(config, "JDP") &&
                                haskey(config["JDP"], "notify") &&
                                haskey(config["JDP"]["notify"], "on-status-diff"))

            for (k, v) in config["JDP"]["notify"]["on-status-diff"]
                patterns = get!(userprefs, k, Set())
                v isa Vector ? push!(patterns, v...) : push!(patterns, v)
            end
        else
            @info "No notify preferences loaded from $(jgroup.name)"
        end
    end

    testprefs = Dict{String, Vector{String}}()
    if invert
        for (user, patterns) = userprefs, p = patterns
            push!(get!(testprefs, p, []), user)
        end
    else
        for (user, patterns) = pairs(userprefs)
            testprefs[user] = collect(patterns)
        end
    end

    testprefs
end

include("OpenQA-indexes.jl")
include("OpenQA-Matrix.jl")

end # json
