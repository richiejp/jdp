import Pkg

try
    @assert JDP isa Module
catch
    # Switch to the JDP project
    pkgpath = normpath(joinpath(dirname(@__FILE__), ".."))
    @info "Activating JDP package at $pkgpath"
    Pkg.activate(pkgpath)

    try
        @eval import JDP
    catch e
        @warn "Exception while importing JDP: $e"
        @info "Will try installing JDP project deps..."
        Pkg.instantiate()
    end

    import JDP

    JDP.Repository.init()
end
