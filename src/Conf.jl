"Gives access to configuration files"
module Conf

using TOML

function __init__()
    global tmp_conf = Dict{Symbol, Dict}()
    global src_path = joinpath(@__DIR__, "../conf")
    global usr_path = joinpath(homedir(), ".config/jdp")
end

Base.get(d::Dict{K}, keychain::Tuple{K}, default) where K =
    get(d, first(keychain), default)

function Base.get(d::Dict{K}, keychain::NTuple{N, K}, default) where {N, K}
    k = first(keychain)

    !haskey(d, k) && return default

    get(d[k]::Dict, keychain[2:end], default)
end

"Override the user specific config path for unit testing"
set_usr_path(path::String) = global usr_path = path

"Used to override the contents of the configuration files for testing (for now)"
set_conf(name::Symbol, conf::Dict) = global tmp_conf[name] = conf

"Like `Base.merge`, but recurses into Dictionaries"
confmerge(base::Any, add::Any) = add
confmerge(base::Any, ::Nothing) = base
confmerge(base::Dict, add::Dict)::Dict = begin
    merged = Dict{String, Any}()

    for key in keys(base)
        merged[key] = confmerge(base[key], get(add, key, nothing))
    end

    merge(add, merged)
end

"""
    get_conf(name::Symbol)::Dict

Get the configuration for `name`. If a temporary in-memory conf has been set
with `set_conf` then it will return that. Otherwise it will return the
contents of `../conf/name.toml` merged with `~/.config/jdp/name.toml`. The
contents of the home directory config win in the event of a conflict."""
get_conf(name::Symbol)::Dict{AbstractString, Any} = get(tmp_conf, name) do
    fname = "$name.toml"
    sconf = joinpath(src_path, fname)
    uconf = joinpath(usr_path, fname)
    if isfile(uconf)
        @debug "Using merge of `$sconf` and `$uconf`"
        confmerge(TOML.parsefile(sconf), TOML.parsefile(uconf))
    else
        @debug "Using `$sconf` only"
        TOML.parsefile(sconf)
    end
end

data(setting::Symbol) = if setting == :datadir
    get_conf(:data)["datadir"] |> expanduser
else
    get_conf(:data)[String(name)]
end

end #module
