@testset "Shell args parsing" begin
    defs = IOHelpers.ShellArgDefs(Set(["baz"]),
                                  Dict("foo" => String,
                                       "wibble" => Vector{String}))
    argsv = split("--foo bar --baz foo bar --wibble wobble,frobble",
                  " ")

    args = IOHelpers.parse_args(defs, argsv)
    @test args.positional == ["foo", "bar"]
    @test args.named["baz"] == true
    @test args.named["foo"] == "bar"
    @test args.named["wibble"] == ["wobble","frobble"]
end
