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

end
