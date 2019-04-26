module RocketChat

using HTTP
import MbedTLS
using JSON

using JDP.Tracker
using JDP.Conf
using JDP.IOHelpers

const emojis = (":robot:", ":japanese_ogre:", ":japanese_goblin:", ":monkey_face:")

struct Session <: Tracker.AbstractSession
    url::String
    ssl::MbedTLS.SSLConfig
    user::String
    token::String
end

Session(host, user, token) = Session(host, IOHelpers.sslconfig(), user, token)
Session() = Session("", "", "")

Tracker.ensure_login!(t::Tracker.Instance{Session}) = if t.session == nothing
    conf = Conf.get_conf(:trackers)["instances"]
    if !haskey(conf, t.tla)
        @warn "No host definition in trackers.toml for $(t.host)"
        return t.session = Session()
    end

    host = conf[t.tla]
    url = "$(t.scheme)://$(t.host)/api/v1"
    if haskey(host, "user") && haskey(host, "token")
        t.session = Session(url, host["user"], host["token"])
    else
        @warn "Rocket Chat instance $(t.host) is missing user and/or token details"
        t.session = Session(url, "", "")
    end
else
    t.session
end

get_raw(ses::Session, path::String) =
    HTTP.get(joinpath(ses.url, path),
             ("X-Auth-Token" => ses.token, "X-User-Id" => ses.user);
             status_exception=true, sslconfig=ses.ssl)

get_json(ses::Session, path::String) =
    JSON.parse(get_raw(ses, path).body |> String)

post_raw(ses::Session, path::String, post::String) =
    HTTP.post(joinpath(ses.url, path),
              ("X-Auth-Token" => ses.token, "X-User-Id" => ses.user),
              post;
              status_exception=true, sslconfig=ses.ssl)

post_json(ses::Session, path::String, post) =
    JSON.parse(post_raw(ses, path, JSON.json(post)).body |> String)

function post_message(ses::Session, room::String, msg::AbstractString)
    j = (channel = room, text = msg, emoji = rand(emojis),
         alias = "JDP Script (rpalethorpe.io.suse.de/jdp/)")
    post_json(ses, "chat.postMessage", j)
end

end
