module Bugzilla

using HTTP
using HTTP.URIs: escapeuri, URI
using XMLDict

const bsc_host = "apibugzilla.suse.com"

struct Session
    host::String
    scheme::String
    userinfo::String

    function Session(host::String, user::String, pass::String)
        new(host, "https", "$user:$pass")
    end
end

function get_xml(ses::Session, path::String; query::String="")::Dict
    uri = URI(scheme=ses.scheme, host=ses.host, path=path,
              userinfo=ses.userinfo, query="ctype=xml&$query")
    @debug "GET $uri"
    HTTP.get(uri, status_exception=true, basic_authorization=true).body |>
        String |> parse_xml
end

function get_bug(ses::Session, id::Int64)::Dict
    get_xml(ses, "/show_bug.cgi", query="id=$id")
end

end # module
