include("install.jl")

import REPL
using REPL.TerminalMenus
using Match

using JDP
using JDP.OpenQA
using JDP.TableDB
using JDP.Conf

json = nothing
df = nothing

selected = request("Load from JSON cache or JLD2 cache?", RadioMenu(["JSON", "JLD2"]))

@match selected begin
    -1 => nothing
    1 => begin
        println("Loading from JSON...")
        json = @time OpenQA.load_job_results_json(Conf.data(:datadir))
        df = @time TableDB.get_module_results(json)
    end
    _ => begin
        println("Loading from JLD2..")
        df = @time TableDB.load_module_results(joinpath(Conf.data(:datadir), "cache.jld2"))
    end
end
