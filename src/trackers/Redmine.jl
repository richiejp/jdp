module Redmine

import HTTP
import JSON

import JDP.Templates
import JDP.Templates: Template, render
import JDP.Conf
import JDP.Tracker
import JDP.Functional: cmap
import JDP.Repository
import JDP.BugRefs

mutable struct Session <: Tracker.AbstractSession
    uri::Templates.Template
end

Tracker.ensure_login!(t::Tracker.Instance{Session}) = if t.session == nothing
    key = get(Conf.get_conf(:trackers)["instances"][t.tla], "key", nothing)
    uri = if key != nothing
        Template("$(t.scheme)://$(t.host){path}.json?key=$key")
    else
        Template("$(t.scheme)://$(t.host){path}.json")
    end

    t.session = Session(uri)
else
    t.session
end

get_json(ses::Session, path::String)::Dict =
    HTTP.get(render(ses.uri, :path => path); status_exception=true).body |>
    String |> JSON.parse

get_issue(ses::Session, id::Int)::Dict =
    get_json(ses, "/issues/$id")["issue"]

abstract type Item <: Repository.AbstractItem end

mutable struct Bug <: Item
    id::Int64
    priority::String
    status::String
    short_desc::String
end

priority_map = Dict("Immediate" => 0, "Urgent" => 1, "High" => 2,
                    "Normal" => 3, "Low" => 4)

Bug(i::Dict) = Bug(i["id"],
                   "P$(priority_map[i["priority"]["name"]]) - " * i["priority"]["name"],
                   i["status"]["name"],
                   i["subject"])

Base.show(io::IO, ::MIME"text/markdown", issue::Bug) =
    write(io, "**", issue.priority, "** ", issue.status, ": ", issue.short_desc)

function Repository.refresh(t::Tracker.Instance{Session}, bref::BugRefs.Ref)::Bug
    ses = Tracker.ensure_login!(t)
    issue = get_issue(ses, parse(Int64, bref.id)) |> Bug

    Repository.store("$(t.tla)-issue-$(bref.id)", issue)
    @info "GOT $bref " issue

    issue
end

function Repository.fetch(::Type{Bug}, bref::BugRefs.Ref)::Union{Bug, Nothing}
    if !(bref.tracker isa Tracker.Instance{Session})
        @error "$bref does not appear to be a Redmine issue"
        return nothing
    end

    issue = Repository.load("$(bref.tracker.tla)-issue-$(bref.id)", Bug)

    if issue != nothing
        issue
    else
        Repository.refresh(bref.tracker, bref)
    end
end

end
