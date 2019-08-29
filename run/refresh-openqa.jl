#!julia

include(joinpath(@__DIR__, "../src/init.jl"))

using JDP.IOHelpers
using JDP.BugRefs
using JDP.Tracker
using JDP.Trackers.OpenQA
using JDP.Repository
using JDP.Spammer

argdefs = IOHelpers.ShellArgDefs(Set(["skipjobs"]), Dict())
args = IOHelpers.parse_args(argdefs, ARGS).named

trackers = [Tracker.get_tracker("osd"), Tracker.get_tracker("ooo")]
errors = []

# OK, so we don't just refresh OpenQA, but also other tracker items we find
# references to
bug_refresh_chnl = Channel{BugRefs.Ref}(256) do c
    seen_bug_ids = Set{Tuple{String, String}}()

    for bref in c
        (bref.tracker.tla, bref.id) in seen_bug_ids && continue

        try
            Repository.refresh(bref)
        catch error
            @error "$(bref.tracker.tla): Failed to refresh bug item $(bref.id)"
            push!(errors, (bref.tracker, error, catch_backtrace()))
        end
    end
end

asyncmap(trackers) do tracker
    try
        jobgroups = filter(Repository.refresh(tracker, OpenQA.JobGroup)) do g
            if (toml = OpenQA.extract_toml(g.description)) == nothing || !haskey(toml, "JDP")
                false
            else
                @info "$(tracker.tla): Found JDP config on Job Group $(g.name) ($(g.id))"
                true
            end
        end

        if !args["skipjobs"]
            Repository.refresh(tracker, jobgroups, bug_refresh_chnl)
            Repository.refresh(OpenQA.RecentOrInterestingJobsDef, tracker.tla)
        else
            @warn "$(tracker.tla): Skipping refreshing the jobs"
        end
    catch error
        @error "$(tracker.tla): Stopping due to an exception: $error"
        push!(errors, (tracker, error, catch_backtrace()))
    end
end

for (tracker, error, backtrace) in errors
    io = IOBuffer()
    showerror(io, error, backtrace)
    exception = String(take!(io))
    @error "While processing $(tracker.tla): $exception"

    msg = """
**Data refresh failed for $(tracker.tla)!** :fearful:
$exception"""
    Spammer.post_message(msg, :rpalethorpe)
end

close(bug_refresh_chnl)
