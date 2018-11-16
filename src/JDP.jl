module JDP

export Repository

include("IOHelpers.jl")
include("Conf.jl")

include("Templates.jl")
include("Repository.jl")
include("trackers/Trackers.jl")
include("BugRefsParser.jl")
include("BugRefs.jl")
#include("TableDB.jl")

Base.include(Trackers, "trackers/Bugzilla.jl")
#Base.include("trackers/Redmine.jl")
Base.include(Trackers, "trackers/OpenQA.jl")


end
