module TableDB

using DataFrames
using Match

import FileIO

using JDP.Trackers
using JDP.BugRefs

function map_result_str(res::String)::String
    if res === "ok"
        "passed"
    elseif res === "fail"
        "failed"
    else
        "none"
    end
end

function get_fstest_results!(cols::Array{Any},
                             jr::Dict{String, Any},
                             tr::Dict{String, Any},
                             tags::Tags)
    setts = jr["settings"]

    for dt in tr["details"]
        name = dt["title"]

        push!(cols[1], setts["BUILD"])
        push!(cols[2], name)
        push!(cols[3], map_result_str(dt["result"]))
        push!(cols[4], setts["ARCH"])
        push!(cols[5], ("fstests", setts["XFSTESTS"]))
        push!(cols[6], get_refs(tags, name))
    end
end

function get_test_results!(cols::Array{Any},
                           jr::Dict{String, Any},
                           tr::Dict{String, Any},
                           tags::Tags)
    setts = jr["settings"]

    if haskey(setts, "XFSTESTS") && tr["name"] == "1_"
        get_fstest_results!(cols, jr, tr, tags)
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
    push!(cols[6], get_refs(tags, name))
    
end

function parse_comments(comments::Array, trackers::TrackerRepo)::Tags
    tags = Tags()

    for c in comments
        extract_tags!(tags, c["text"], trackers)
    end

    tags
end

function get_module_results(job_results::Array{Dict{String, Any}})
    trackers = load_trackers()
    columns::Array{Any} = [String[] for _ in 1:4]
    push!(columns, Tuple{String, Union{String, Missing}}[])
    push!(columns, Array{BugRefs.Ref}[])

    for jr in job_results
        tags = parse_comments(jr["comments"], trackers)

        for tr in jr["testresults"]
            get_test_results!(columns, jr, tr, tags)
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
