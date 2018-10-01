using JDP.OpenQA
using JDP.TableDB

@testset "Integration Tests" begin
    println("Loading json data: ")
    json = @time OpenQA.load_job_results_json("./data")
    @test length(json) > 0

    println("Converting to DataFrames: ")
    df = @time TableDB.get_module_results(json)
    @test length(df) > 0
end
