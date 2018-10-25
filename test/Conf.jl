using JDP.Conf

@testset "Configuration loading" begin
    datadir = Conf.data(:datadir)
    @test datadir != ""
    @test !occursin("~", datadir)
end
