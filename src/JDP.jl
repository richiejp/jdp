module JDP

export Repository

include("Functional.jl")
include("IOHelpers.jl")
include("Conf.jl")

include("Templates.jl")
include("Lazy.jl")
include("trackers/Tracker.jl")
include("BugRefsParser.jl")
include("BugRefs.jl")
include("Repository.jl")
include("Spammer.jl")

module Trackers
include("trackers/Bugzilla.jl")
include("trackers/Redmine.jl")
include("trackers/OpenQA.jl")
include("trackers/RocketChat.jl")
include("trackers/Mailx.jl")
end

end
