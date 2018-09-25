module TableDB

using DataFrames
using Match

struct ModBugRefs
    specific::Dict{String, Array{String}}
    general::Array{String}
end

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
                             tr::Dict{String, Any})
    setts = jr["settings"]

    for dt in tr["details"]
        push!(cols[1], setts["BUILD"])
        push!(cols[2], dt["title"])
        push!(cols[3], map_result_str(dt["result"]))
        push!(cols[4], setts["ARCH"])
        push!(cols[5], ("fstests", setts["XFSTESTS"]))
    end
end

function get_test_results!(cols::Array{Any},
                           jr::Dict{String, Any},
                           tr::Dict{String, Any})
        setts = jr["settings"]

        if haskey(setts, "XFSTESTS") && tr["name"] == "1_"
            get_fstest_results!(cols, jr, tr, setts)
            return
        end
        
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
end

function parse_bugref_comments(comments::Array{Dict{String, Any}})::Dict{String, Array{String}}
    spec = Dict{String, Array{String}}()
    gen = Array{String}()

    for c in comments
        parse_bugref!(spec, gen, c["text"])
    end

    ModBugRefs(spec, gen)
end

function get_module_results(job_results::Array{Dict{String, Any}})
    columns::Array{Any} = [String[] for _ in 1:4]
    push!(columns, Tuple{String, Union{String, Missing}}[])

    for jr in job_results
        refs = parse_bugref_comments(jr["comments"])

        for tr in jr["testresults"]
            get_test_results!(columns, jr, tr)
        end
    end

    DataFrame(columns, [:build, :name, :result, :arch, :suit])
end

end
