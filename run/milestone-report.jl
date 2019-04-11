#!julia

include(joinpath(@__DIR__, "../src/init.jl"))

using Markdown
import Base.Iterators: flatten

using JDP.IOHelpers
using JDP.BugRefs
using JDP.Tracker
using JDP.Trackers.OpenQA
using JDP.Trackers.Bugzilla
using JDP.Trackers.Redmine
using JDP.Repository
import JDP.Functional: cimap, cforeach

argdefs = IOHelpers.ShellArgDefs(Set(["refresh"]), Dict(
    "product_short" => String,
    "products" => Vector{String},
    "release" => String,
    "builds" => Vector{String}
))

args = try
    args
catch
    IOHelpers.parse_args(argdefs, ARGS).named
end

refresh = get!(args, "refresh", false)
allres = get!(args, "results") do
    Repository.fetch(OpenQA.TestResult, Vector, "osd")
end
product_short = get!(args, "product_short", "SLE15 SP1")
products = get!(args, "products", ["sle-15-SP1"])
release = get!(args, "release", "Beta3")
builds = get!(args, "builds", ["152.1"])

trackers = Tracker.load_trackers()

refdict = Dict{BugRefs.Ref, Vector{OpenQA.TestResult}}(
    BugRefs.Ref(rf, trackers) => [] for rf in [
        # Extra bugs can be added here manually
        # "bsc#1126782",
        # "bsc#1126215"
    ]
)

Iterators.filter(allres) do t
    (t.build in builds) && !isempty(t.refs) &&
        any(prefix -> startswith(t.product, prefix), products)
end |> cimap() do t
    (rf => t for rf in t.refs)
end |> flatten |> cforeach() do (rf, t)
    push!(get!(Vector{OpenQA.TestResult}, refdict, rf), t)
end

bugdict = get!(args, "bugs") do
    brefs = collect(keys(refdict))
    if refresh
        Repository.refresh(brefs)
    end

    Dict(rf => Repository.fetch(rf) for rf in brefs)
end

println("""
# $product_short $release $(join(builds, ", ")) Kernel Acceptance Test Report

This was partially generated with the [JDP milestone report](https://gitlab.suse.de/rpalethorpe/jdp/blob/master/run/milestone-report.jl)

## Summary

[Insert human generated summary here]

The following test groups are covered:

- Kernel
- Network
- HPC
- Public Cloud

Anomalies not in these groups, but relevant to our team's testing, may also be
included.

## Critical Issues

""")

iscrit(bug::Bugzilla.Bug) =
    startswith(bug.priority, "P0") || startswith(bug.priority, "P1") ||
    bug.severity == "Critical"
iscrit(bug::Redmine.Bug) =
    startswith(bug.priority, "P0") || startswith(bug.priority, "P1")

function print_bug_item(rf, bug)
    print("- ")
    show(stdout, MIME("text/markdown"), rf)
    print(" ")
    show(stdout, MIME("text/markdown"), bug)
    println()
    for t in refdict[rf]
        print("   * ")
        show(stdout, MIME("text/markdown"), t)
        println()
    end
end

totals = Dict()
for (rf, bug) in bugdict
    if iscrit(bug)
        print_bug_item(rf, bug)
    else
        prio = bug.priority[1:2]
        totals[prio] = 1 + get(totals, prio, 0)
    end
end

println("""

## Other Issues

Below are the bug counts by priority. These include all issues and bugs which
have been associated with a failing test case or other anomaly in this build.
""")

for prio in sort(collect(keys(totals)))
    println("* $prio = $(totals[prio])")
end

