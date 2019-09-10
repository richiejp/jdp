import Distributed: @everywhere, procs, myid

try
    @assert JDP isa Module
catch
    # Switch to the JDP project
    pkgpath = normpath(joinpath(dirname(@__FILE__), ".."))
    @info "Activating JDP package at $pkgpath"
    @everywhere begin
        import Pkg
        Pkg.activate($pkgpath)
    end

    try
        @eval import JDP
    catch e
        @warn "Exception while importing JDP: $e"
        @info "Will try installing JDP project deps..."
        Pkg.instantiate()
    end

    @everywhere import JDP
    all_except_me = [id for id in procs() if id != myid()]
    @everywhere all_except_me JDP.Repository.init()
end
