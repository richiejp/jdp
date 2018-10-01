import Pkg 

Pkg.activate("./")
Pkg.instantiate()

using JDP
using JDP.OpenQA
using JDP.TableDB

println("Loading...")
json = @time OpenQA.load_job_results_json("/home/rich/qa/data/osd")
df = @time TableDB.get_module_results(json)
