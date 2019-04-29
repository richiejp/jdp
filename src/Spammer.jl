"Broadcast messages using multiple Trackers"
module Spammer

using JDP.Tracker

"""Generic message body and meta data

- body: The message text. Some trackers may use the first line as the subject.
- mentions: Users or accounts to 'mention' (Rocket Chat) or CC (email). 
            Usually this means adding something like `@user` to the message.

Trackers may interpret the message content differently. However each tracker
should try to use the given information in a way which is analogous to the
other trackers.
"""
struct Message
    body::AbstractString
    mentions::Vector{String}
end

"Trackers may implement this to be included in broadcast messages"
post_message(tracker::Tracker.Instance, msg::Message) =
    @debug "post_message not implemented" tracker

"Send message using all trackers configured for sending broadcasts"
function post_message(msg::Message)
    for tracker in values(load_trackers().instances)
        post_message(tracker, msg)
    end
end

end
