module JDP

export Repository

include("Functional.jl")
include("IOHelpers.jl")
include("Conf.jl")

include("Templates.jl")
include("trackers/Tracker.jl")
include("BugRefsParser.jl")
include("BugRefs.jl")
include("Repository.jl")

module Trackers
include("trackers/Bugzilla.jl")
include("trackers/Redmine.jl")
include("trackers/OpenQA.jl")
include("trackers/RocketChat.jl")
end

end
