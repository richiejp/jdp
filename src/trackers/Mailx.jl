"Sends e-mails with the mailx command"
module Mailx

using JDP.Tracker
using JDP.Spammer
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

function post_message(ses::Session, to::AbstractString,
                      subject::AbstractString, msg::AbstractString)
    sout = IOBuffer()
    eout = IOBuffer()
    env = ("MAILRC" => "/dev/null", "from" => ses.from, "smtp" => ses.smtp)

    withenv(env...) do
        run(pipeline(`mailx -n -s "$subject" $to`;
                     stdin=IOBuffer(msg), stdout=sout, stderr=eout))
    end

    let sout = String(take!(sout)), eout = String(take!(eout))
        isempty(sout) || @info sout
        isempty(eout) || @error eout
    end
end

function Spammer.post_message(t::Tracker.Instance{Session}, msg::Spammer.Message)
    ses = Tracker.ensure_login!(t)

    firstnl = findfirst(isequal('\n'), msg.body)
    if firstnl ≠ nothing && firstnl < length(msg.body)
        post_message(ses, ses.from, msg.body[1:firstnl], msg.body)
    else
        @debug "Ignoring broadcast message" msg ses
    end
end

end
