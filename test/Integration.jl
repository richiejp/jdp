using JDP.Trackers
using JDP.BugRefs
using JDP.Trackers.OpenQA
using JDP.TableDB

@testset "Integration Tests" begin
    println("Loading json data: ")
    json = @time OpenQA.load_job_results_json("./data")
    @test length(json) > 0

    println("Converting to DataFrames: ")
    df = @time TableDB.get_module_results(json)
    @test length(df) > 0

    ts = load_trackers()
    bref(s) = BugRefs.Ref(s, ts)
    bugrefs = foldr(df.bugrefs) do x, xs
        vcat(xs, x...)
    end |> unique
    @test bref("poo#40400") in bugrefs
    @test bref("poo#40403") in bugrefs
    @test bref("t#2009216") in bugrefs
    @test bref("boo#1111342") in bugrefs
    @test bref("poo#41684") in bugrefs
    @test bref("t#779350") in bugrefs
    @test length(unique(bugrefs)) == 6
end
