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

argdefs = IOHelpers.ShellArgDefs(Set(["norefresh"]), Dict())
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


if !args["norefresh"]
    @info "Refreshing all comments for latest build: $(latest[2])"

    OpenQA.refresh_comments(job -> job.vars["BUILD"] == latest[2], "osd")
end

@info "Generating Reports in `$reppath`"

weave(joinpath(@__DIR__, "../notebooks/Report-DataFrames.ipynb");
      doctype="md2html", out_path=reppath)

weave(joinpath(@__DIR__, "../notebooks/Report-HPC.ipynb");
      doctype="md2html", out_path=reppath)

module MilestoneSandbox

args = Dict{String, Any}("builds" => [Main.latest[2]], "results" => Main.allres)
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
