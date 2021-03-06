using Distributed

test_procs = []

@info "Julia currently has $(nprocs()) processes/workers"
if nprocs() < 5
    @info "Adding local workers to test distributed code"
    test_procs = addprocs(5 - nprocs())
end

using Test
using DataFrames
import TOML

import JDP
import JDP.Functional
import JDP.Functional: cmap, cforeach, cfilter, cifilter, cdoif, cdefault
using JDP.Conf
using JDP.IOHelpers
using JDP.Templates
using JDP.Tracker
using JDP.Trackers.OpenQA
using JDP.BugRefs
using JDP.BugRefsParser
using JDP.Repository

@testset "All" begin
    include("Conf.jl")
    include("IOHelpers.jl")
    include("Templates.jl")
    include("trackers/Trackers.jl")
    include("trackers/OpenQA.jl")
    include("BugRefs.jl")
    include("Metarules.jl")
    include("Integration.jl")
end

rmprocs(test_procs...)
