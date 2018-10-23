#!julia
using Pkg

pkgpath = normpath(joinpath(dirname(@__FILE__), ".."))
println("Activating JDP package at $pkgpath")
Pkg.activate(pkgpath)

println("Installing project deps if necessary...")
Pkg.instantiate()
