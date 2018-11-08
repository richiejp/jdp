module Templates

export @template_str, Template, render

using HTTP.URIs: escapeuri

abstract type Option end
abstract type Encoding <: Option end
struct PercentEncode <: Encoding end

struct Var
    name::Symbol
    options::Vector{Option}
end

Base.:(==)(u::Var, uo::Var) = u.name == uo.name

struct OpenBracketError <: Exception msg::String end
struct CloseBracketError <: Exception msg::String end
struct EOSError <: Exception msg::String end

struct Template
    parts::Vector{Union{String, Var}}
end

function Template(text::String, options::Option...)::Template
    tmpl = Vector{Union{String, Var}}()
    part = IOBuffer()
    seen_bracket = false

    opts::Vector{Option} = length(options) < 1 ? [] : [options...]

    for (i::Int, c::Char) in enumerate(text)
        if c == '{' && seen_bracket
            throw(OpenBracketError("Found nested '{' at $i: $text"))
        elseif c == '}' && !seen_bracket
            throw(CloseBracketError("Found '}' without matching '{' at $i: $text"))
        elseif c == '{' || c == '}'
            if part.size > 0
                s = take!(part)
                push!(tmpl, seen_bracket ? Var(Symbol(s), opts) : String(s))
            end
            seen_bracket = !seen_bracket
        else
            write(part, c)
        end
    end

    if seen_bracket
        throw(EOSError("Expected '}' found end of string: $text"))
    elseif part.size > 0
        push!(tmpl, String(take!(part)))
    end

    Template(tmpl)
end

macro template_str(text)
    Template(text)
end

function render(io::IO, tmpl::Template, vars::Dict{Symbol})::Int
    written::Int = 0

    for part in tmpl.parts
        if part isa Var
            val = vars[Symbol(part.name)]

            for opt in part.options
                if opt isa PercentEncode
                    # I really hate unecessary allocations in places like this
                    val = escapeuri(val)
                end
            end

            written += write(io, val)
        else
            written += write(io, part)
        end
    end

    written
end
render(io::IO, tmpl::Template, vars::Pair{Symbol}...)::Int =
    render(io, tmpl, Dict(vars))

end
