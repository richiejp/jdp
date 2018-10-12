module Bugzilla

using HTTP
using HTTP.URIs: escapeuri
using XMLDict

const Host = String
bsc = Host("https://bugzilla.suse.com/")

mutable struct Session
    host::Host
    jar::Dict{String, Set{HTTP.Cookie}}
end

function post_form(ses::Session, path::String, body::String)
    res = HTTP.get(joinpath(ses.host, path);
                   redirect=true, status_exception=true,
                   cookies=true, cookiejar=ses.jar)
    redirect_host = res.request.headers["Host"]
    HTTP.post("https://$redirect_host/",
              ["Content-Type" => "application/x-www-form-urlencoded"],
              body;
              redirect=true, status_exception=true,
              cookies=true, cookiejar=ses.jar)
end

function login(host::Host, user::String, pass::String)::Session
    uri = "index.cgi?GoAheadAndLogIn=1"
    ses = Session(host, Dict())
    form = "Ecom_User_ID=$(escapeuri(user))&Ecom_password=$(escapeuri(pass))&option=credential&target="

    resp = post_form(ses, uri, form)
    @debug("POST $uri: $form ⏎\n", resp)

    ses
end

function get_xml(ses::Session, path::String)::Dict
    uri = joinpath(ses.host, path)
    @debug "GET $uri"
    HTTP.get(uri, status_exception=true, cookies=true, cookiejar=ses.jar).body |>
        String |> parse_xml
end

function get_bug(ses::Session, id::Int64)::Dict
    get_xml(host, "show_bug.cgi?ctype=xml&id=$id")
end

end # module
