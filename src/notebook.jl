import Pkg

# We need to add IJulia to the shared/home project, otherwise Jupyter might
# not be able to start it.
Pkg.activate()
Pkg.add("IJulia")

using IJulia

curdir = dirname(@__FILE__)

if curdir != ""
    notebook(dir = curdir)
else
    notebook()
end
