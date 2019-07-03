#!julia

include(joinpath(@__DIR__, "../src/init.jl"))

using JDP.IOHelpers
using JDP.Tracker
using JDP.Trackers.OpenQA
using JDP.Repository

argdefs = IOHelpers.ShellArgDefs(Set(["skipjobs"]), Dict())
args = IOHelpers.parse_args(argdefs, ARGS).named

trackers = [Tracker.get_tracker("osd"), Tracker.get_tracker("ooo")]

asyncmap(trackers) do tracker
    jobgroups = filter(Repository.refresh(tracker, OpenQA.JobGroup)) do g
        if (toml = OpenQA.extract_toml(g.description)) == nothing || !haskey(toml, "JDP")
            false
        else
            @info "$(tracker.tla): Found JDP config on Job Group $(g.name) ($(g.id))"
            true
        end
    end

    if !args["skipjobs"]
        Repository.refresh(tracker, jobgroups)
        Repository.refresh(OpenQA.RecentOrInterestingJobsDef, tracker.tla)
    else
        @warn "$(tracker.tla): Skipping refreshing the jobs"
    end
end
