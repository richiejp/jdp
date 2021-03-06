using Pkg

include(joinpath(@__DIR__, "../src/init.jl"))

using Documenter

using JDP
import JDP.IOHelpers: ShellArgDefs, parse_args
import JDP.BugRefsParser

args = parse_args(ShellArgDefs(Set(["clean"]), Dict()), ARGS).named

pages = [
    "Home" => "index.md",
    "Bug Tagging" => "bug-tagging.md",
    "User Preferences" => "user-preferences.md",
    "Reference" => [
        "BugRefs" => "bugrefs.md",
        "Metarules" => "metarules.md",
        "Conf" => "conf.md",
        "Functional" => "functional.md",
        "Repository" => "repository.md",
        "Trackers" => "trackers.md"
    ],
    "Development" => "development.md"
]

if isdir(joinpath(@__DIR__, "build/reports"))
    push!(pages, "Reports" => "reports.md")
end

makedocs(
    modules = [JDP],
    format = Documenter.HTML(assets = ["assets/favicon.ico"]),
    sitename = "JDP",
    clean = args["clean"],
    pages = pages,
    repo = "https://github.com/richiejp/jdp"
)

