using JDP.Templates
import JDP.Templates: Var, PercentEncode

@testset "Text/URI Templates" begin
    tmpl = template"foo/bar"
    @test tmpl.parts[1] == "foo/bar"

    tmpl = template"https://{host}"
    @test tmpl.parts[1] == "https://"
    @test tmpl.parts[2] == Var(:host, [])

    tmpl = template"{host}/bar/{id}"
    @test tmpl.parts[1] == Var(:host, [])
    @test tmpl.parts[2] == "/bar/"
    @test tmpl.parts[3] == Var(:id, [])

    tmpl = Template("foo/{thing}", PercentEncode())
    buf = IOBuffer()
    @test render(buf, tmpl, :thing => "&stringy%") > 0
    @test String(take!(buf)) == "foo/%26stringy%25"

    # Can't use api"" string macro here because the exception gets wrapped in
    # a LoadError
    @test_throws Templates.OpenBracketError Template("foo{{host}bar")
    @test_throws Templates.CloseBracketError Template("foo}bar")
    @test_throws Templates.EOSError Template("{host")
end
