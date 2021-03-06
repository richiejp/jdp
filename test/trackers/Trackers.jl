const SS = Tracker.StaticSession

@testset "Trackers" begin
    conf = TOML.parsefile(joinpath(@__DIR__, "../conf/trackers.toml"))
    repo = load_trackers(conf)
    api = repo.apis["Foos"]
    @test api == Api{SS}("Foos", template"/bar/show_bug.cgi?id={id}")
    @test get_tracker(repo, "foo") ==
        Tracker.Instance{SS}(api, nothing, "foo", "wss", "foo.suse.com")

    repo = load_trackers()
    @test length(repo.instances) > 0 && length(repo.apis) > 0
end
