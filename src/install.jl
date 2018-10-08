#!julia
using Pkg

println("Installing project deps...")
Pkg.activate(joinpath(@__FILE__, ".."))
Pkg.instantiate()

# TODO install data sets
