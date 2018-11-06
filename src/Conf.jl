module Conf

using TOML

confdir = joinpath(dirname(@__FILE__), "../conf/")

function get_conf(name::Symbol)::Dict
    TOML.parsefile(joinpath(confdir, "$name.toml"))
end

function substitute_home(path::String)::String
    replace(path, '~' => homedir(); count = 1)
end

data(setting::Symbol) = if setting == :datadir
    get_conf(:data)["datadir"] |> substitute_home
else
    get_conf(:data)[String(name)]
end

end #module
