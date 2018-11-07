using JDP.Trackers
import JDP.Trackers: ApiUrl, UrlVar

@testset "Trackers" begin
    repo = Trackers.load_trackers()

    @test length(repo.instances) > 0 && length(repo.apis) > 0

    url = api"foo/bar"
    @test url[1] == "foo/bar"

    url = api"https://{host}"
    @test url[1] == "https://"
    @test url[2] == UrlVar("host")

    url = api"{host}/bar/{id}"
    @test url[1] == UrlVar("host")
    @test url[2] == "/bar/"
    @test url[3] == UrlVar("id")

    # Can't use api"" string macro here because the exception gets wrapped in
    # a LoadError
    @test_throws Trackers.OpenBracketError ApiUrl("foo{{host}bar")
    @test_throws Trackers.CloseBracketError ApiUrl("foo}bar")
    @test_throws Trackers.EOSError ApiUrl("{host")
end
