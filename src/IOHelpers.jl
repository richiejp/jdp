module IOHelpers

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

# Should really upstream this into MbedTLS.jl
sslconfig()::MbedTLS.SSLConfig = begin
    ssl = MbedTLS.SSLConfig(true)
    MbedTLS.ca_chain!(ssl, MbedTLS.crt_parse_file("/etc/ssl/ca-bundle.pem"))
    ssl
end

end #module
