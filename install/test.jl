#!julia

include(joinpath(@__DIR__, "../src/init.jl"))

Pkg.test(coverage=false)
