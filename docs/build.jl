using Pkg

include("../src/init.jl")

using Documenter

using JDP
import JDP.IOHelpers: ShellArgDefs, parse_args
import JDP.BugRefsParser

args = parse_args(ShellArgDefs(Set(["clean"]), Dict()), ARGS).named

makedocs(
    modules = [JDP],
    format = Documenter.HTML(),
    sitename = "JDP",
    clean = args["clean"],
    pages = [
        "Home" => "index.md",
        "Reference" => [
            "BugRefs" => "bugrefs.md",
            "Conf" => "conf.md",
            "Functional" => "functional.md",
            "Repository" => "repository.md",
            "Trackers" => "trackers.md"
        ],
        "Development" => "development.md"
    ]
)

