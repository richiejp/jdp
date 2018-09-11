using JSON
using HTTP

openqa_url = "https://openqa.opensuse.org/api/v1"

function get_json(path::String)
    req = HTTP.request("GET", "$openqa_url/$path")
    if req.status == 200
        JSON.parse(String(req.body))
    else
        throw("Request failed: $req")
    end
end

function get_machines()
    get_json("machines")["Machines"]
end

function get_group_jobs(group_id::Int64)
    get_json("job_groups/$group_id/jobs")["ids"]
end

function get_job_results(job_id::Int64)
    get_json("jobs/$job_id/details")["job"]
end

function flatten(arr::Array)
    map(flatten, arr)
end

function flatten(dict::Dict{String, Any})
    dc = copy(dict)
    delete!(dc, "settings")
    setts::Dict{String, Any} = Dict()
    for s in dict["settings"]
        setts[s["key"]] = s["value"]
    end
    dc["settings"] = setts
    dc
end

function load_job_results_json(dir_path::String)
    dir = realpath(dir_path)
    readdir(dir) |>
        names -> map(n -> "$dir/$n", names) |>
        paths -> filter(isfile, paths) |>
        files -> map(f -> JSON.parsefile(f)["job"], files)
end

function save_job_results_json(dir_path::String, group_id::Int64)
    dir_path = realpath(dir_path)
    if !isdir(dir_path)
        throw("Not a directory $dir_path")
    end

    jgrps = get_group_jobs(group_id)
    i = 1
    N = length(jgrps)
    for jid in jgrps
        url = "$openqa_url/jobs/$jid"
        file = "$dir_path/$jid.json"
        @info "$i/$N GET $url"
        req = HTTP.get(url, status_exception = true)
        @info "$i/$N WRITE $file"
        open(f -> write(f, req.body), file, "w")
        i += 1
    end
end
