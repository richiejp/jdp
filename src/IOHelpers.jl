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

end #module
