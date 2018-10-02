module TableDB

using DataFrames
using Match

import FileIO

using ..BugRefs

BugRefDict = Dict{Union{BugRefs.TestName, String}, Array{BugRefs.BugRef}}

function map_result_str(res::String)::String
    if res === "ok"
        "passed"
    elseif res === "fail"
        "failed"
    else
        "none"
    end
end

function map_bugrefs_to_test(name::String, refs::BugRefDict)::Array{SubString}
    arefs = SubString[]

    if haskey(refs, BugRefs.WILDCARD)
        append!(arefs, map(tokval, refs[BugRefs.WILDCARD]))
    end
    if haskey(refs, name)
        append!(arefs, map(tokval, refs[columns[2]]))
    end

    arefs
end

function get_fstest_results!(cols::Array{Any},
                             jr::Dict{String, Any},
                             tr::Dict{String, Any},
                             refs::BugRefDict)
    setts = jr["settings"]

    for dt in tr["details"]
        name = dt["title"]

        push!(cols[1], setts["BUILD"])
        push!(cols[2], name)
        push!(cols[3], map_result_str(dt["result"]))
        push!(cols[4], setts["ARCH"])
        push!(cols[5], ("fstests", setts["XFSTESTS"]))
        push!(cols[6], map_bugrefs_to_test(name, refs))
    end
end

function get_test_results!(cols::Array{Any},
                           jr::Dict{String, Any},
                           tr::Dict{String, Any},
                           refs::BugRefDict)
    setts = jr["settings"]

    if haskey(setts, "XFSTESTS") && tr["name"] == "1_"
        get_fstest_results!(cols, jr, tr, refs)
        return
    end

    name = tr["name"]
        
    push!(cols[1], setts["BUILD"])
    push!(cols[2], tr["name"])
    push!(cols[3], tr["result"])
    push!(cols[4], setts["ARCH"])
    push!(cols[5], if haskey(setts, "LTP_COMMAND_FILE")
          ("LTP", setts["LTP_COMMAND_FILE"])
    elseif haskey(setts, "XFSTESTS")
          ("fstests", setts["XFSTESTS"])
    else
          ("OpenQA", get(tr, "category", missing))
    end)
    push!(cols[6], map_bugrefs_to_test(name, refs))
    
end

"Push one test name to many bugrefs mapping"
function push_tag!(tags::Dict{Union{BugRefs.TestName, String}, Array{BugRefs.BugRef}},
                   name::BugRefs.TestName,
                   head_ref::BugRefs.BugRef,
                   rest_refs::Union{Array{BugRefs.BugRef}, Nothing})
    refs = get!(tags, name, String[])

    push!(refs, head_ref)
    if rest_refs !== nothing
        for rr in rest_refs
            push!(refs, rr)
        end
    end
end

function parse_comments(comments::Array)::BugRefDict
    spec = BugRefDict()

    for c in comments
        (tags, _) = BugRefs.parse_comment(c["text"])
        for t in tags
            push_tag!(spec, t.test, t.ref, t.refs)
            if t.tests !== nothing
                for tn in t.tests
                    push_tag!(spec, tn, t.ref, t.refs)
                end
            end
        end
    end

    spec
end

function get_module_results(job_results::Array{Dict{String, Any}})
    columns::Array{Any} = [String[] for _ in 1:4]
    push!(columns, Tuple{String, Union{String, Missing}}[])
    push!(columns, Array{SubString}[])

    for jr in job_results
        refs = parse_comments(jr["comments"])

        for tr in jr["testresults"]
            get_test_results!(columns, jr, tr, refs)
        end
    end

    DataFrame(columns, [:build, :name, :result, :arch, :suit, :bugrefs])
end

function save_module_results(path::String, df::DataFrame)
    FileIO.save(path, "test_results", df)
end

function load_module_results(path::String)::DataFrame
    FileIO.load(path, "test_results")
end

end
