module IOHelpers

using IJulia: readprompt

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

end #module
