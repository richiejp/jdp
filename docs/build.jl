using Pkg

include("../src/init.jl")

using Documenter

using JDP
import JDP.IOHelpers: ShellArgDefs, parse_args
import JDP.BugRefsParser

args = parse_args(ShellArgDefs(Set(["clean"]), Dict()), ARGS).named

makedocs(
    modules = [JDP],
    format = :html,
    sitename = "JDP",
    clean = args["clean"],
    pages = [
        "Home" => "index.md",
        "Reference" => [
            "JDP.BugRefs" => "bugrefs.md"
        ],
        "Development" => "development.md"
    ]
)

