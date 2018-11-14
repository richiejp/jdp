using JDP.Trackers

@testset "Trackers" begin
    repo = load_trackers()

    @test length(repo.instances) > 0 && length(repo.apis) > 0
end
