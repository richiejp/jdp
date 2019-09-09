using Test

using JDP.Metarules

@testset "Metarules" begin
    simple = "[flavor=GCE]"
    noise = "{α$simple[12]"

    rule = Metarules.extract(simple)[1]
    @test rule.op == :(==)
    @test rule.name == "flavor"
    @test rule.value == "GCE"

    rule = Metarules.extract(noise)[1]
    @test rule.op == :(==)
    @test rule.name == "flavor"
    @test rule.value == "GCE"
end
