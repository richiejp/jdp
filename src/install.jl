#!julia
using Pkg

@info "Installing IJulia"

# We need to add IJulia to the shared/home project, otherwise Jupyter might
# not be able to start it.
Pkg.activate()
Pkg.add("IJulia")

# Ensure the module can be used
import IJulia

# Activate the JDP project
include("init.jl")

# Sanity check the installation by running JDP's tests
Pkg.test(coverage=false)
