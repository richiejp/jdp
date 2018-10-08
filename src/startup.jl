import Pkg
import REPL
using REPL.TerminalMenus
using Match

Pkg.activate("./")
Pkg.instantiate()

using JDP
using JDP.OpenQA
using JDP.TableDB

datadir = "/home/rich/qa/data/osd"
json = nothing
df = nothing

selected = request("Load from JSON cache or JLD2 cache?", RadioMenu(["JSON", "JLD2"]))

@match selected begin
    -1 => nothing
    1 => begin
        println("Loading from JSON...")
        json = @time OpenQA.load_job_results_json(datadir)
        df = @time TableDB.get_module_results(json)
    end
    _ => begin
        println("Loading from JLD2..")
        df = @time TableDB.load_module_results(joinpath(datadir, "cache.jld2"))
    end
end
