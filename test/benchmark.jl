module Benchmark

using Profile
using BSONqs
const BSON = BSONqs

export do_bench, do_profile

struct Result
  elapsed::Float64
  allocated::Int64
end

const history_file = "./benchmark-history.bson"

macro bench(hist, msg, ex)
  sex = "$ex"
  quote
    GC.gc()
    @info $msg
    local val, t1, bytes, gctime, memallocs = @timed $(esc(ex))
    local mb = ceil(bytes / (1024 * 1024))
    if $sex in keys($(esc(hist)))
      local t0 = $(esc(hist))[$sex].elapsed
      @info $sex elapsed=t1 speedup=t0/t1 allocatedMb=mb gctime
    else
      @info $sex elapsed=t1 allocatedMb=mb gctime
    end
    $(esc(hist))[$sex] = Result(t1, bytes)
    val
  end
end

include("../src/init.jl")

import JDP.Repository
import JDP.Trackers.OpenQA

function do_bench()
  hist = if isfile(history_file)
    BSON.load(history_file)::Dict{String, Result}
  else
    Dict{String, Result}()
  end

  jr = @bench hist "Fetch OpenQA Job Results" Repository.fetch(OpenQA.JobResult, Vector, "osd")
  jr = length(jr)
  tr = @bench hist "Fetch OpenQA Test Results" Repository.fetch(OpenQA.TestResult, Vector, "osd")
  tr = length(tr)

  bson(history_file, hist)

  "$jr Job Results and $tr Test Results"
end

function do_profile(minc)
  Profile.init(;n=10000000)

  @info "Profile Fetch OpenQA Job Results"
  @profile Repository.fetch(OpenQA.JobResult, Vector, "osd")
  Profile.print(;noisefloor=2, mincount=minc, C=true)
end

end
