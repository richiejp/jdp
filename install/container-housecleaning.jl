#!julia

using Dates
using JSON

dryrun = "--dry-run" in ARGS

get_containers()::Vector = let ids = split(read(`docker ps --all --quiet`, String))
    read(`docker inspect $ids`, String) |>
    JSON.Parser.parse
end

get_images()::Vector = let ids = split(read(`docker images --quiet`, String))
    read(`docker inspect $ids`, String) |>
    JSON.Parser.parse
end

dfstr = "yyyy-mm-dd"
parse_docker_date(str)::DateTime = DateTime(str[1:length(dfstr)], dfstr)

conts_whitelist = ["/redis"]
images_whitelist = ["jdp:latest", "jdp:production", "jdp-base:latest",
                    "opensuse/tumbleweed:latest"]

thetime = now()

for cont in get_containers()
    created = parse_docker_date(cont["Created"])
    age = floor(thetime - created, Day)

    amsg = "Container is $age old"
    if cont["Name"] in conts_whitelist
        @info "$amsg: Keeping (whitelisted)" cont["Name"] cont["Path"]
    elseif cont["State"]["Status"] != "exited"
        @info "$amsg: Keeping (Status != exited)" cont["Name"] cont["Path"]
    elseif age >= Day(3)
        @warn "$amsg: Removing" cont["Name"] cont["Path"]
        if !dryrun
            run(`docker rm $(cont["Id"])`)
        end
    else
        @debug "$amsg: Keeping (age < 3 days)" cont["Name"] cont["Path"]
    end
end

for img in get_images()
    created = parse_docker_date(img["Created"])
    age = floor(thetime - created, Day)

    amsg = "Image is $age old"
    if any(tag -> tag in images_whitelist, img["RepoTags"])
        @info "$amsg: Keeping (whitelisted)" img["Id"] img["RepoTags"]
    elseif age >= Day(3)
        @warn "$amsg: Removing" img["Id"] img["RepoTags"]
        if !dryrun
            try
                run(`docker rmi -f $(img["Id"])`)
            catch error
                @error "Could not delete image (this may be OK if it is still being used)" error
            end
        end
    else
        @debug "$amsg: Keeping (age < 3 days)" img["Id"] img["RepoTags"]
    end
end

if !dryrun
    run(`docker image prune --force`)
    run(`docker volume prune --force`)
end
