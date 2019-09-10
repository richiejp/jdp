using Test

using JDP.Metarules

@testset "Metarules" begin
    simple = "[flavor=GCE]"
    noise = "{α$simple[12]"
    numeric = """["is numeric"=1, a_float=3.141]"""
    errors = """
[ok=1, not_ok=0x1][55=1.2, Symbol("foo")=bar, f=x->x, g=()]
[[[foo=bar]]]
[ok=2]
"""

    rule = Metarules.extract(simple)[1]
    @test rule.op == :(==)
    @test rule.name == "flavor"
    @test rule.value == "GCE"

    rule = Metarules.extract(noise)[1]
    @test rule.op == :(==)
    @test rule.name == "flavor"
    @test rule.value == "GCE"

    rules = Metarules.extract(numeric)
    @test rules[1].op == :(==)
    @test rules[1].name == "is numeric"
    @test rules[1].value == 1
    @test rules[2].op == :(==)
    @test rules[2].name == "a_float"
    @test rules[2].value == 3.141

    rules = Metarules.extract(errors)
    @test length(rules) == 2
    @test rules[1].op == :(==)
    @test rules[1].name == "ok"
    @test rules[1].value == 1
    @test rules[2].op == :(==)
    @test rules[2].name == "ok"
    @test rules[2].value == 2
end
