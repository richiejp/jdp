using Test

@testset "All" begin
    include("Conf.jl")
    include("BugRefs.jl")
    include("Integration.jl")
end
