#!julia

include("../src/init.jl")

using JDP.BugRefs
using JDP.Trackers
using JDP.Trackers.OpenQA
using JDP.Trackers.Bugzilla
using JDP.Repository
using JDP.Functional
using JDP.Conf

allres = Repository.fetch(OpenQA.TestResult, Vector, "osd"; refresh=true, groupid=116)

@info "We now have $(length(allres)) test results!"

latest = reduce((parse(Float64, test.build), test.build) for test in allres) do b, o
    b[1] > o[1] ? b : o
end

OpenQA.refresh_comments(job -> job.vars["BUILD"] == latest[2], "osd")
