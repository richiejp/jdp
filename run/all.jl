#!julia

include("../src/init.jl")

using Weave

using JDP.IOHelpers
using JDP.BugRefs
using JDP.Trackers.OpenQA
using JDP.Trackers.Bugzilla
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

allres = Repository.fetch(OpenQA.TestResult, Vector, "osd";
                          refresh=!args["norefresh"], groupid=116)

@info "We now have $(length(allres)) test results!"

latest = reduce((parse(Float64, test.build), test.build) for test
                in allres if test.product == "sle-15-SP1-Installer-DVD") do b, o
    b[1] > o[1] ? b : o
end

args["build"] = latest[2]
@info "Latest build is $(latest[2]); propagating bug tags"
weave(joinpath(@__DIR__, "../notebooks/Propagate Bug Tags.ipynb");
      doctype="md2html", out_path=reppath, args=args)

if !args["norefresh"]
    @info "Refreshing comments after bug tag propagation"

    OpenQA.refresh_comments(job -> job.vars["BUILD"] == latest[2], "osd")
end

@info "Generating Reports in `$reppath`"

weave_ipynb("Report-DataFrames");
weave_ipynb("Report-HPC");

module MilestoneSandbox

args = Dict{String, Any}("builds" => [Main.latest[2]])
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
