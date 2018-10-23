module Bugzilla

using HTTP
using HTTP.URIs: escapeuri, URI
using XMLDict

const bsc_host = "apibugzilla.suse.com"

mutable struct Session
    host::String
    scheme::String
    userinfo::String
    jar::Dict{String, Set{HTTP.Cookie}}

    function Session(host::String, user::String, pass::String)
        new(host, "https", "$user:$pass", Dict())
    end
end

function login!(ses::Session)
    uri = URI(scheme=ses.scheme, host=ses.host, path="/", userinfo=ses.userinfo)

    HTTP.get(uri; status_exception=true, basic_authorization=true,
             cookies=true, cookiejar=ses.jar)
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

end # module
