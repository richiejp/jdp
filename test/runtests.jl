using Distributed

test_procs = []

@info "Julia currently has $(nprocs()) processes/workers"
if nprocs() < 5
    @info "Adding local workers to test distributed code"
    test_procs = addprocs(5 - nprocs())
end

using Test

@testset "All" begin
    include("Conf.jl")
    include("Templates.jl")
    include("Trackers.jl")
    include("BugRefs.jl")
    include("Integration.jl")
end

rmprocs(test_procs...)
