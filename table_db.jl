module table_db

using DataFrames
using ..TestResults

function get_module_results(job_results::Array{Dict{String, Any}})
    columns = [String[] for _ in 1:5]

    for jr = job_results, tr = jr["testresults"]
        setts = jr["settings"]
        push!(columns[1], setts["BUILD"])
        push!(columns[2], tr["name"])
        push!(columns[3], tr["result"])
        push!(columns[4], setts["ARCH"])
        if haskey(setts, "LTP_COMMAND_FILE")
            push!(columns[5], "LTP:" * setts["LTP_COMMAND_FILE"])
        else
            push!(columns[5], "OpenQA")
        end
    end

    DataFrame(columns, [:build, :name, :result, :arch, :suit])
end

end
