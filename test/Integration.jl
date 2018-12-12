@testset "Integration Tests" begin
    Conf.set_conf(:data, Dict("datadir" => joinpath(@__DIR__, "data")))

    tests = @test_nowarn Repository.fetch(OpenQA.TestResult, Vector, "osd")

    ts = load_trackers()
    bref(s) = BugRefs.Ref(s, ts)
    bugrefs = vcat(map(t -> t.refs, tests)...) |> unique
    @test bref("poo#40400") in bugrefs
    @test bref("poo#40403") in bugrefs
    @test bref("t#2009216") in bugrefs
    @test bref("boo#1111342") in bugrefs
    @test bref("poo#41684") in bugrefs
    @test bref("t#779350") in bugrefs
    @test length(unique(bugrefs)) == 6

    df = @test_nowarn Repository.fetch(OpenQA.TestResult, DataFrame, "osd")
    @test df.name[1] == tests[1].name
end
