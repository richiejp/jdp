module TestResults

using ..json

@enum TestResultStatus begin
    Passed
    Failed
    Unknown
end

function TestResultStatus(s::String)::TestResultStatus
    if s === "passed"
        Passed
    elseif s === "failed"
        Failed
    else
        Unknown
    end
end

struct ModResult{T}
    build::String
    name::String
    result::TestResultStatus
    arch::String
    test::T
end

struct LTPResult
    suit::String
end

function get_module_results(job_results::Array{Dict{String, Any}})::Array{ModResult}
    res = ModResult[]
    for jr = job_results, tr = jr["testresults"]
        setts = jr["settings"]
        test = if haskey(setts, "LTP_COMMAND_FILE")
            LTPResult(setts["LTP_COMMAND_FILE"])
        else
            nothing
        end

        push!(res, ModResult(setts["BUILD"],
                             tr["name"],
                             TestResultStatus(tr["result"]),
                             setts["ARCH"],
                             test))
    end
    res
end

function get_module_results(dir_path::String)
    get_module_results(json.load_job_results(dir_path))
end

end
