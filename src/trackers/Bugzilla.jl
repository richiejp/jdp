module Bugzilla

using HTTP
using HTTP.URIs: escapeuri, URI
using Markdown
import Markdown: MD, Link, Paragraph, LineBreak, Bold, Italic
using XMLDict
import IJulia

import JDP.IOHelpers: prompt
import JDP.Conf
using JDP.Trackers

mutable struct Session <: Trackers.AbstractSession
    host::String
    scheme::String
    userinfo::String
    jar::Dict{String, Set{HTTP.Cookie}}

    function Session(host::String, user::String, pass::String)
        new(host, "https", "$user:$pass", Dict())
    end
end

function login(host_tla::String)::Union{Session, Nothing}
    conf = Conf.trackers(host_tla)

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

Trackers.ensure_login!(t::Tracker{Session}) = if t.session == nothing
    t.session = login(t.tla)
else
    login!(t.session)
end

function get_xml(ses::Session, path::String; query::String="")::Dict
    uri = URI(scheme=ses.scheme, host=ses.host, path=path, query="ctype=xml&$query")
    @debug "GET $uri"
    HTTP.get(uri, status_exception=true, cookies=true, cookiejar=ses.jar).body |>
        String |> parse_xml
end

function get_bug(ses::Session, id::Int64)::Dict
    get_xml(ses, "/show_bug.cgi", query="id=$id")["bug"]
end

function to_md(bug::Dict)::MD
    stat = bug["bug_status"]
    sevr = bug["bug_severity"]
    prio = bug["priority"]
    desc = bug["short_desc"]

    MD(Paragraph([Bold(prio), "(", Italic(sevr), ") ", stat, ": ", desc]))
end

end # module
