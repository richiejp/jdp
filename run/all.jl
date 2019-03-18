#!julia

include("../src/init.jl")

using Weave

using JDP.IOHelpers
using JDP.BugRefs
using JDP.Tracker
using JDP.Trackers.OpenQA
using JDP.Repository
using JDP.Functional
using JDP.Conf

weave_ipynb(name::String) =
    weave(joinpath(@__DIR__, "../notebooks/$name.ipynb");
          doctype="md2html", out_path=reppath)

argdefs = IOHelpers.ShellArgDefs(Set(["norefresh", "dryrun"]), Dict())
args = IOHelpers.parse_args(argdefs, ARGS).named

reppath = joinpath(Conf.data(:datadir), "reports")
if !ispath(reppath)
    @warn "Reports directory `$reppath` doesn't exist, I will try creating it"
    mkdir(reppath)
end

tracker = Tracker.get_tracker("osd")
jobgroups = [OpenQA.JobGroup(id, name) for (id, name) in [
    116 => "Kernel",
    117 => "Network",
    130 => "HPC",
    219 => "Public Cloud"
]]

if !args["norefresh"]
    Repository.refresh(tracker, jobgroups)
end
allres = Repository.fetch(OpenQA.TestResult, Vector, tracker.tla)

@info "We now have $(length(allres)) test results!"

build_tuples = (parse(Float64, test.build) => test.build for test
                in allres if test.product == "sle-15-SP1-Installer-DVD")
latest = reduce(build_tuples, init=0 => "0") do b, o
    b[1] > o[1] ? b : o
end

build_tuples = (parse(Float64, test.build) => test.build for test
                in allres if startswith(test.product, "sle-15-SP1") &&
                get(test.job.vars, "PUBLIC_CLOUD", nothing) != nothing)
latest_pc = reduce(build_tuples, init=0 => "0") do b, o
    b[1] > o[1] ? b : o
end

builds = [latest[2], latest_pc[2]]
args["builds"] = builds
@info "Latest build is $(latest[2]) (Public Cloud $(latest_pc[2])); propagating bug tags"
weave(joinpath(@__DIR__, "../notebooks/Propagate Bug Tags.ipynb");
      doctype="md2html", out_path=reppath, args=args)

if !args["norefresh"]
    @info "Refreshing comments after bug tag propagation"

    OpenQA.refresh_comments(job -> job.vars["BUILD"] in builds, tracker.tla)
end

@info "Generating Reports in `$reppath`"

weave_ipynb("Report-DataFrames");
weave_ipynb("Report-HPC");

module MilestoneSandbox

args = Dict{String, Any}("builds" => Main.builds)
try
    @info "Running run/milestone-report.jl"
    open(joinpath(Main.reppath, "Milestone-Report.md"), "w") do io
        redirect_stdout(io) do
            include(joinpath(@__DIR__, "milestone-report.jl"))
        end
    end
catch exception
    @error "run/milestone-report.jl failed" exception
end

end
