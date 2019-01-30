using Markdown
import Base.Iterators: flatten

using JDP.BugRefs
using JDP.Trackers
using JDP.Trackers.OpenQA
using JDP.Trackers.Bugzilla
using JDP.Repository
import JDP.Functional: cimap, cforeach

allres = get!(args, "results") do
    Repository.fetch(OpenQA.TestResult, Vector, "osd"; refresh=false, groupid=116)
end
product_short = get(args, "product_short", "SLE15 SP1")
product = get(args, "product", "sle-15-SP1-Installer-DVD")
release = get(args, "release", "Beta3")
build = get(args, "build", "152.1")

refdict = Dict{BugRefs.Ref, Vector{OpenQA.TestResult}}()

Iterators.filter(allres) do t
    t.build == build && !isempty(t.refs) && t.product == product
end |> cimap() do t
    (rf => t for rf in t.refs)
end |> flatten |> cforeach() do (rf, t)
    push!(get!(Vector{OpenQA.TestResult}, refdict, rf), t)
end

bugdict = get!(args, "bugs") do
    brefs = collect(keys(refdict))
    Repository.refresh(brefs)

    Dict(rf => Repository.fetch(Bugzilla.Bug, rf) for
         rf in brefs if rf.tracker.tla == "bsc" || rf.tracker.tla == "boo")
end

println("""
# $product_short $release $build Kernel Acceptance Test Report

The formatted version of this report is here:

## Summary

[Insert human generated summary here]

## Critical Issues

""")

iscrit(bug) = startswith(bug.priority, "P1") ||
    (startswith(bug.priority, "P5") && bug.severity == "Critical")

function print_bug_item(rf, bug)
    show(stdout, MIME("text/markdown"), "- $rf $bug")
    for t in refdict[rf]
        show(stdout, MIME("text/markdown"), "   * $t")
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

get_prio(kv) = kv[2].priority[1:2]

sbugs = sort(pairs(bugdict); by=get_prio)

for (rf, bug) in sbugs
    if !iscrit(bug)
        print_bug_item(rf, bug)
    end
end

for (rf, tsts) in refdict
    if !haskey(bugdict, rf)
        show(stdout, MIME("text/markdown"), "- $rf *(No summary data)*")
        for t in refdict[rf]
            show(stdout, MIME("text/markdown"), "   * $t")
        end
    end
end
