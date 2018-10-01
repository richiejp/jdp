using Test

using JDP

@testset "All" begin
    include("BugRefs.jl")
    include("Integration.jl")
end
