module json

using JSON
using HTTP

struct OpenQAHost
    url::String
end

o3 = OpenQAHost("https://openqa.opensuse.org/api/v1")
osd = OpenQAHost("http://openqa.suse.de/api/v1")

function get_json(host::OpenQAHost, path::String)
    HTTP.get(joinpath(host.url, path), status_exception=true).body |>
        String |> JSON.parse
end

function get_machines(host::OpenQAHost)
    get_json(host, "machines")["Machines"]
end

function get_group_jobs(host::OpenQAHost, group_id::Int64)::Array{Int64}
    get_json(host, "job_groups/$group_id/jobs")["ids"]
end

function get_job_results(host::OpenQAHost, job_id::Int64)
    get_json(host, "jobs/$job_id/details")["job"]
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
        names -> map(n -> joinpath(dir, n), names) |>
        paths -> filter(isfile, paths) |>
        files -> filter(f -> endswith(f, "job-details.json"), files) |>
        files -> asyncmap(files) do f
            js = JSON.parsefile(f)["job"]
            cfile = joinpath(dir, "$(js["id"])-job-comments.json")
            if isfile(cfile)
                js["comments"] = JSON.parsefile(cfile)
            else
                @debug "Missing comments file for job $(js["id"])"
                js["comments"] = []
            end
            js
        end
end

function save_job_json(host::OpenQAHost,
                       jid::Integer,
                       dir_path::String,
                       i::Integer, N::Integer,
                       ext::String="")
    url = joinpath(host.url, "jobs", "$jid", ext)
    file = joinpath(dir_path, "$jid-job-$ext.json")
    if !isfile(file)
        @info "$i/$N GET $url"
        req = HTTP.get(url, status_exception = true)
        @info "$i/$N WRITE $file"
        open(f -> write(f, req.body), file, "w")
    else
        @debug "$i/$N SKIP $url"
    end
end

function save_job_results_json(host::OpenQAHost, dir_path::String, group_id::Int64)
    dir_path = realpath(dir_path)
    if !isdir(dir_path)
        throw("Not a directory $dir_path")
    end

    jgrps = get_group_jobs(host, group_id)
    i = 1
    N = length(jgrps)
    for jid in jgrps
        sjob = ext -> save_job_json(host, jid, dir_path, i, N, ext)
        sjob("details")
        sjob("comments")
        i += 1
    end
end

end # json
