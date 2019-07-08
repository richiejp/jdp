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

argdefs = IOHelpers.ShellArgDefs(Set(["norefresh", "dryrun"]),
                                 Dict("host" => String))
args = IOHelpers.parse_args(argdefs, ARGS).named
get!(args, "host", "osd")

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

weave_ipynb("Propagate Bug Tags", args)

@info "Generating Reports in $reppath"

try
    @info "Creating Milestone Sandbox on worker $(myid())"
    #Evaluate the report script in a dynamically created namespace
    MilestoneSandbox = Module(:MilestoneSandbox)

    # It appears include(x) is not created for us when using Module directly
    Base.eval(MilestoneSandbox,
              :(include(x) = Base.include($MilestoneSandbox, x)))

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

weave_ipynb("Report-Status-Diff");
