module JDP

export OpenQA, TableDB, BugRefs

include("OpenQA.jl")
include("BugRefsParser.jl")
include("BugRefs.jl")
include("TableDB.jl")

end
