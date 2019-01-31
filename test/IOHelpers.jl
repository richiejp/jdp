@testset "Shell args parsing" begin
    defs = IOHelpers.ShellArgDefs(Set(["baz"]),
                                  Set(["foo"]))
    argsv = split("--foo bar --baz foo bar", " ")

    args = IOHelpers.parse_args(defs, argsv)
    @test args.positional == ["foo", "bar"]
    @test args.named["baz"] == true
    @test args.named["foo"] == "bar"
end
