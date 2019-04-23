module Benchmark

using Profile
using BSON

struct Result
  elapsed::Float64
  allocated::Int64
end

const history_file = "./benchmark-history.bson"
history = if isfile(history_file)
    BSON.load(history_file)::Dict{String, Result}
else
    Dict{String, Result}()
end

macro bench(msg, ex)
  sex = "$ex"
  quote
    GC.gc()
    @info $msg
    local val, t1, bytes, gctime, memallocs = @timed $(esc(ex))
    local mb = ceil(bytes / (1024 * 1024))
    if $sex in keys(history)
      local t0 = history[$sex].elapsed
      @info $sex elapsed=t1 speedup=t0/t1 allocatedMb=mb gctime
    else
      @info $sex elapsed=t1 allocatedMb=mb gctime
    end
    history[$sex] = Result(t1, bytes)
    val
  end
end

include("../src/init.jl")

import JDP.Repository
import JDP.Trackers.OpenQA

@bench "Fetch OpenQA Test Results" Repository.fetch(OpenQA.TestResult, Vector, "osd")

@info "Profile Fetch OpenQA Test Results"
@profile Repository.fetch(OpenQA.TestResult, Vector, "osd")
Profile.print(;noisefloor=2, mincount=50)

end
