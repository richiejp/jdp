module IOHelpers

using FileIO
using IJulia: readprompt
import MbedTLS

function prompt(msg::String; password=false)::String
    try
        readprompt("$msg: "; password=password)
    catch
        if password
            write(stdout, "[INPUT WILL BE VISIBLE!] ")
        end
        write(stdout, msg, ": ")
        readline()
    end
end

function show_debug(level, filename, number, msg)
    @debug "[MbedTLS($level) $filename:$number] $msg"
end

# Should really upstream this into MbedTLS.jl
sslconfig()::MbedTLS.SSLConfig = begin
    conf = MbedTLS.SSLConfig(true)
    MbedTLS.dbg!(conf, show_debug)
    MbedTLS.ca_chain!(conf, MbedTLS.crt_parse_file("/etc/ssl/ca-bundle.pem"))
    conf
end

struct ShellArgs
    positional::Vector{AbstractString}
    named::Dict{AbstractString, Any}
end

struct ShellArgDefs
    flags::Set{AbstractString}
    named::Dict{AbstractString, Type}
end

function parse_args(defs::ShellArgDefs, argsv::Vector{S})::ShellArgs where {S <: AbstractString}
    positional = S[]
    named = Dict{S, Any}()
    itr = iterate(argsv)

    for flag in defs.flags
        named[flag] = false
    end

    while itr != nothing
        (arg, state) = itr

        if sizeof(arg) > 2 && startswith(arg, "--")
            name = arg[3:end]

            if name in defs.flags
                named[name] = true
            elseif haskey(defs.named, name)
                itr = iterate(argsv, state)

                if itr == nothing
                    error("Expected a value after '$arg'")
                else
                    (arg, state) = itr
                    named[name] = defs.named[name] <: Vector ? split(arg, ",") : arg
                end
            else
                error("Unrecognised argument '$arg'")
            end
        else
            push!(positional, arg)
        end

        itr = iterate(argsv, state)
    end

    ShellArgs(positional, named)
end

end #module
