module Bugzilla

using HTTP
using HTTP.URIs: escapeuri, URI
using Markdown
import Markdown: MD, Link, Paragraph, LineBreak, Bold, Italic
using XMLDict
import IJulia

import JDP.IOHelpers: prompt
import JDP.Conf
using JDP.Tracker
import JDP.Functional: cmap
using JDP.Repository
using JDP.BugRefs

mutable struct Session <: Tracker.AbstractSession
    host::String
    scheme::String
    userinfo::String
    jar::Dict{String, Set{HTTP.Cookie}}

    function Session(host::String, user::String, pass::String)
        new(host, "https", "$user:$pass", Dict())
    end
end

function login(host_tla::String)::Union{Session, Nothing}
    conf = Conf.get_conf(:trackers)["instances"][host_tla]

    if conf["api"] != "Bugzilla"
        throw("$host_tla is not a Bugzilla instance, but instead $(conf["api"])")
    end

    user = get(conf, "user") do
        prompt("User Name")
    end

    pass = get(conf, "pass") do
        prompt("Password"; password=true)
    end

    login(conf["host"], user, pass)
end

function login(host::String, user::String, pass::String)::Union{Session, Nothing}
    ses = Session(host, user, pass)

    login!(ses).status < 300 ? ses : nothing
end

function login!(ses::Session)
    uri = URI(scheme=ses.scheme, host=ses.host, path="/", userinfo=ses.userinfo)

    HTTP.get(uri; status_exception=true, basic_authorization=true,
             cookies=true, cookiejar=ses.jar)
end

Tracker.ensure_login!(t::Tracker.Instance{Session}) = if t.session == nothing
    t.session = login(t.tla)
else
    login!(t.session).status < 300 ? t.session : nothing
end

function get_xml(ses::Session, path::String; query::String="")::Dict
    uri = URI(scheme=ses.scheme, host=ses.host, path=path, query="ctype=xml&$query")
    @debug "GET $uri"
    HTTP.get(uri, status_exception=true, cookies=true, cookiejar=ses.jar).body |>
        String |> parse_xml
end

function get_raw_bug(ses::Session, id::Int64)::Dict
    get_xml(ses, "/show_bug.cgi", query="id=$id")["bug"]
end

function get_raw_bug(from::String, id::Int64)::Dict
    t = get_tracker(load_trackers(), from)
    get_raw_bug(Tracker.ensure_login!(t), id)
end

abstract type Item <: Repository.AbstractItem end

mutable struct Bug <: Item
    id::Int64
    severity::String
    priority::String
    status::String
    short_desc::String
end

Bug(xml::Dict) = Bug(parse(Int, xml["bug_id"]),
                     xml["bug_severity"],
                     xml["priority"],
                     xml["bug_status"],
                     xml["short_desc"])

Base.show(io::IO, ::MIME"text/markdown", bug::Bug) =
    write(io, "**", bug.priority, "**(*", bug.severity, "*) ", bug.status, ": ",
          bug.short_desc)

function to_md(bug::Dict)::MD
    stat = bug["bug_status"]
    sevr = bug["bug_severity"]
    prio = bug["priority"]
    desc = bug["short_desc"]

    MD(Paragraph([Bold(prio), "(", Italic(sevr), ") ", stat, ": ", desc]))
end

function Repository.refresh(t::Tracker.Instance{Session}, bref::BugRefs.Ref)::Bug
    ses = Tracker.ensure_login!(t)
    bug = get_raw_bug(ses, parse(Int64, bref.id)) |> Bug

    Repository.store("$(t.tla)-bug-$(bref.id)", bug)
    @info "GOT $bref " bug

    bug
end

function Repository.fetch(::Type{Bug}, bref::BugRefs.Ref)::Union{Bug, Nothing}
    if !(bref.tracker isa Tracker.Instance{Session})
        @error "$bref does not appear to be a Bugzilla Bug"
        return nothing
    end

    bug = Repository.load("$(bref.tracker.tla)-bug-$(bref.id)", Bug)

    if bug != nothing
        bug
    else
        Repository.refresh(bref.tracker, bref)
    end
end

function Repository.fetch(::Type{Bug}, ::Type{Vector}, from::String)::Vector{Bug}
    trackers = load_trackers()
    tracker = get_tracker(trackers, from)

    Repository.mload("$from-bug-*", Bug)
end

end # module
