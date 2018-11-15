using TOML

using JDP.Conf

@testset "Configuration loading" begin
    Conf.set_usr_path(joinpath(@__DIR__, "conf"))

    datadir = Conf.data(:datadir)
    @test datadir != ""
    @test !occursin("~", datadir)

    ts = Conf.get_conf(:trackers)
    @test ts["instances"]["foo"]["api"] == "Foos"
    @test ts["instances"]["bsc"]["api"] == "Bugzilla"
    @test ts["instances"]["bsc"]["user"] == "geekotest"
    @test ts["instances"]["bsc"]["pass"] == "n0ts3cr3t"

    tconf = TOML.parsefile(joinpath(@__DIR__, "conf/trackers.toml"))
    Conf.set_conf(:trackers, tconf)
    ts = Conf.get_conf(:trackers)
    @test !haskey(ts["instances"], "boo")
    @test haskey(ts["instances"], "foo")
end
