@testset "Shell args parsing" begin
    defs = IOHelpers.ShellArgDefs(Set(["baz"]),
                                  Dict("foo" => String,
                                       "wibble" => Vector{String},
                                       "meaning" => Int,
                                       "A" => Vector{Int}))
    argsv = split("--foo bar --baz foo bar --wibble wobble,frobble --meaning 42 --A 1,2,3",
                  " ")

    args = IOHelpers.parse_args(defs, argsv)
    @test args.positional == ["foo", "bar"]
    @test args.named["baz"] == true
    @test args.named["foo"] == "bar"
    @test args.named["wibble"] == ["wobble","frobble"]
    @test args.named["meaning"] == 42
    @test args.named["A"] == [1, 2, 3]
end
