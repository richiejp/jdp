#!julia

include(joinpath(@__DIR__, "../src/init.jl"))

import Distributed: @spawn, @everywhere, @sync, myid
@everywhere using Weave
@everywhere import Highlights

using JDP.IOHelpers
using JDP.BugRefs
using JDP.Tracker
using JDP.Trackers.OpenQA
using JDP.Repository
using JDP.Functional
using JDP.Conf

argdefs = IOHelpers.ShellArgDefs(Set(["norefresh", "dryrun"]), Dict())
args = IOHelpers.parse_args(argdefs, ARGS).named

reppath = joinpath(Conf.data(:datadir), "reports")
if !ispath(reppath)
    @warn "Reports directory `$reppath` doesn't exist, I will try creating it"
    mkdir(reppath)
end

@everywhere weave_ipynb(name::String, args=Dict()) = try
    cd(joinpath(@__DIR__, "../notebooks")) do
        @info "Weaving $(joinpath(pwd(), name)).ipynb on worker $(myid())"
        weave("$name.ipynb"; doctype="md2html",
              css="weave.css", highlight_theme=Highlights.Themes.GitHubTheme,
              out_path=$reppath, args=args)
    end
catch exception
    @error "Exception while weaving $name" exception
end

tracker = Tracker.get_tracker("osd")
jobgroups = [OpenQA.JobGroup(id) for (id) in (
    116, #Kernel
    117, #Network
    130, #HPC
    219  #Public Cloud
)]

if !args["norefresh"]
    Repository.refresh(tracker, jobgroups)
    Repository.refresh(OpenQA.RecentOrInterestingJobsDef, "osd")
end
allres = Repository.fetch(OpenQA.TestResult, Vector, tracker.tla,
                          OpenQA.RecentOrInterestingJobsDef)

@info "We now have $(length(allres)) test results!"

build_tuples = (parse(Float64, test.build) => test.build for test
                in allres if test.product == "sle-15-SP1-Installer-DVD")
latest = reduce(build_tuples, init=0 => "0") do b, o
    b[1] > o[1] ? b : o
end

build_tuples = (parse(Float64, test.build) => test.build for test
                in allres if startswith(test.product, "sle-15-SP1") &&
                "Public Cloud" in test.flags)
latest_pc = reduce(build_tuples, init=0 => "0") do b, o
    b[1] > o[1] ? b : o
end

allres = nothing # Avoid OOM killer

builds = [latest[2], latest_pc[2]]
args["builds"] = builds
@info "Latest build is $(latest[2]) (Public Cloud $(latest_pc[2]))"
weave_ipynb("Propagate Bug Tags", args)

if !args["norefresh"]
    @info "Refreshing comments after bug tag propagation"

    OpenQA.refresh_comments(job -> job.vars["BUILD"] in builds, tracker.tla)
end

GC.gc()
@info "Generating Reports in $reppath"

try
    @info "Creating Milestone Sandbox on worker $(myid())"
    #Evaluate the report script in a dynamically created namespace
    MilestoneSandbox = Module(:MilestoneSandbox)

    # It appears include(x) is not created for us when using Module directly
    Base.eval(MilestoneSandbox, quote
              include(x) = Base.include($MilestoneSandbox, x)
              args = Dict{String, Any}("builds" => $builds)
              end)

    @info "Running run/milestone-report.jl on worker $(myid())"
    output = joinpath(reppath, "Milestone-Report.md")
    open(output, "w") do io
        redirect_stdout(io) do
            Base.include(MilestoneSandbox,
                         joinpath(@__DIR__, "milestone-report.jl"))
        end
    end
    @info "Written $output"
catch exception
    @error "Milestone Report Error" exception
end

weave_ipynb("Report-DataFrames", Dict("builds" => builds));
weave_ipynb("Report-HPC");
weave_ipynb("Report-Status-Diff");
