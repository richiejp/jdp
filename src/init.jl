using Pkg

# Switch to the JDP project
pkgpath = normpath(joinpath(dirname(@__FILE__), ".."))
@info "Activating JDP package at $pkgpath"
Pkg.activate(pkgpath)

@info "Installing JDP project deps if necessary..."
Pkg.instantiate()
