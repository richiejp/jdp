include("../src/init.jl")

import HTTP
import EzXML: parsehtml, findall
import Dates: monthabbr_to_value, Date, Day, ENGLISH, now

using JDP.IOHelpers
using JDP.Spammer
using JDP.Repository

const schedsuri = "https://projects.nue.suse.com/schedules/"

function sget(uri)
    @info "GET $uri"
    HTTP.get(uri; status_exception=true, sslconfig=IOHelpers.sslconfig()).body |>
        String
end

get_schedule_files(uri)::Vector{AbstractString} =
    [l.content for l in findall("//a", parsehtml(sget(uri)))
     if l.content == l["href"]]

function get_latest_sched_names(filenames)
    matches = [match(r"(.*?)-Schedule-(\d+\.\d+)\.txt", l) for l in filenames]
    scheds = [(name=m[1], ver=parse(Float64, m[2]), file=m.match) for m in matches if m ≠ nothing]

    ret = Dict{String, NamedTuple}()
    for s in scheds
        if get!(ret, s.name, s).ver < s.ver
            ret[s.name] = s
        end
    end

    ret
end

get_sched_strs(baseuri, filenames) =
    [sget(joinpath(baseuri, file)) for file in filenames]

function get_latest_sched_strs(baseuri::String)::Vector{AbstractString}
    files = get_schedule_files(baseuri)
    names = get_latest_sched_names(files)
    get_sched_strs(baseuri, (n.file for n in values(names)))
end

function parse_sched(schedstr)
    prod = match(r"Product:\s*(.*)\n", schedstr)[1]
    parts = split(schedstr, "------------------------------------------------------------------------------")
    matches = [match(r"(Mon|Tue|Wed|Thu|Fri), (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (\d+), (\d+)(:?\s+((:?Alpha|Beta|RC|GMC|GM)\d*))", p) for p in parts]
    matches = filter(!(isnothing), matches)
    events = map(matches) do m
        (product = prod, weekday = m[1], month = m[2], day = m[3], year = m[4], release = strip(m[5]))
    end
end

parse_scheds(schedstrs) = (parse_sched(s) for s in schedstrs)
parse_sched_events(schedstrs) = collect(Iterators.flatten(parse_scheds(schedstrs)))

function create_date_index(events)
    i = Dict()
    for ev in events
        d = Date(parse(Int64, ev.year), monthabbr_to_value(ev.month, ENGLISH), parse(Int64, ev.day))
        push!(get!(i, d, []), ev)
    end

    i
end

function get_in_date_range(indx, range::UnitRange)
    today = Date(now())

    collect(Iterators.flatten(get(indx, today + Day(n), []) for n in range))
end

function create_msgs(index)
    msgs = Spammer.Message[]

    for e in get(index, Date(now()), [])
        tf = "check-schedule-$(e.product)-$(e.release)-today"
        if Repository.get_temp_flag(tf) == nothing
            push!(msgs, Spammer.Message("$(e.product) $(e.release) was scheduled for today", []))
            Repository.set_temp_flag(tf, repr(now()), Day(1))
        end
    end

    for e in get_in_date_range(index, 1:6)
        tf = "check-schedule-$(e.product)-$(e.release)-this-week"
        if Repository.get_temp_flag(tf) == nothing
            push!(msgs, Spammer.Message(
                "$(e.product) $(e.release) is scheduled for the coming $(e.weekday)", []))
            Repository.set_temp_flag(tf, repr(now()), Day(7))
        end
    end

    for e in get_in_date_range(index, 7:13)
        tf = "check-schedule-$(e.product)-$(e.release)-next-week"
        if Repository.get_temp_flag(tf) == nothing
            push!(msgs, Spammer.Message(
                "$(e.product) $(e.release) is scheduled for $(e.weekday) $(e.day)", []))
            Repository.set_temp_flag(tf, repr(now()), Day(7))
        end
    end

    msgs
end

function doit()
    schedstrs = get_latest_sched_strs(schedsuri)
    events = parse_sched_events(schedstrs)
    index = create_date_index(events)
    msgs = create_msgs(index)

    for msg in msgs
        @info "Sending" msg
        Spammer.post_message(msg)
    end

    index
end
