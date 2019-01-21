using Pkg

Pkg.activate()
Pkg.add("Documenter")

include("../src/init.jl")

# This is intentionally not included as a project dependency
using Documenter

using JDP
import JDP.BugRefsParser

makedocs(
    modules = [JDP],
    format = :html,
    sitename = "JDP",
    pages = [
        "Home" => "index.md",
        "Reference" => [
            "JDP.BugRefs" => "bugrefs.md"
        ],
        "Development" => "development.md"
    ]
)

