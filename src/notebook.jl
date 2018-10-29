#!julia
import Pkg

# We need to add IJulia to the shared/home project, otherwise Jupyter might
# not be able to start it.
Pkg.activate()
Pkg.add("IJulia")

using IJulia

notebookdir = joinpath(dirname(@__FILE__), "..", "notebooks")

if notebookdir != ""
    notebook(dir = notebookdir)
else
    notebook()
end
