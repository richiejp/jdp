#!julia

include(joinpath(@__DIR__, "../src/init.jl"))

using Markdown
import Base.Iterators: flatten

using JDP.IOHelpers
using JDP.BugRefs
using JDP.Trackers
using JDP.Trackers.OpenQA
using JDP.Trackers.Bugzilla
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
    Repository.fetch(OpenQA.TestResult, Vector, "osd"; refresh=refresh, groupid=116)
end
product_short = get!(args, "product_short", "SLE15 SP1")
products = get!(args, "products", ["sle-15-SP1-Installer-DVD"])
release = get!(args, "release", "Beta3")
builds = get!(args, "builds", ["152.1"])

refdict = Dict{BugRefs.Ref, Vector{OpenQA.TestResult}}()

Iterators.filter(allres) do t
    (t.build in builds) && !isempty(t.refs) && (t.product in products)
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

    Dict(rf => Repository.fetch(Bugzilla.Bug, rf) for
         rf in brefs if rf.tracker.tla == "bsc" || rf.tracker.tla == "boo")
end

println("""
# $product_short $release $(join(builds, ", ")) Kernel Acceptance Test Report

This was partially generated with the [JDP milestone report](https://gitlab.suse.de/rpalethorpe/jdp/blob/master/run/milestone-report.jl)

## Summary

[Insert human generated summary here]

## Critical Issues

""")

iscrit(bug) = startswith(bug.priority, "P1") ||
    (startswith(bug.priority, "P5") && bug.severity == "Critical")

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
       
for (rf, bug) in bugdict
    if iscrit(bug)
        print_bug_item(rf, bug)
    end
end

println("""
## Other Issues

""")

get_prio(bpair) = bpair[2].priority[1:2]

sbugs = sort(collect(bugdict); by=get_prio)

for (rf, bug) in sbugs
    if !iscrit(bug)
        print_bug_item(rf, bug)
    end
end

for (rf, tsts) in refdict
    if !haskey(bugdict, rf)
        print("- ")
        show(stdout, MIME("text/markdown"), rf)
        println(" *(No summary data)*")
        for t in refdict[rf]
            print("   * ")
            show(stdout, MIME("text/markdown"), t)
            println()
        end
    end
end
