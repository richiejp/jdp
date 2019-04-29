module Mailx

using JDP.Tracker
using JDP.Conf
using JDP.IOHelpers

struct Session <: Tracker.AbstractSession
    from::String
    smtp::String
end

Tracker.ensure_login!(t::Tracker.Instance{Session}) = if t.session == nothing
    conf = Conf.get_conf(:trackers)["instances"][t.tla]
    t.session = Session(conf["from"], conf["smtp"])
else
    t.session
end

function post_message(ses::Session,
                      to::AbstractString, subject::AbstractString, msg::IO)
    sout = IOBuffer()
    eout = IOBuffer()

    withenv("MAILRC" => "/dev/null", "from" => ses.from, "smtp" => ses.smtp) do
        run(pipeline(`mailx -n -s "$subject" $to`;
                     stdin=msg, stdout=sout, stderr=eout))
    end

    let sout = String(take!(sout)), eout = String(take!(eout))
        isempty(sout) || @info sout
        isempty(eout) || @error eout
    end
end

post_message(ses::Session, to::S, subject::S, msg::S) where {S <: AbstractString} =
    post_message(ses, to, subject, IOBuffer(msg))

end
