module BugRefs

using Match

struct Cursor
    line::Int
    col::Int
    c::Char
    i::Int
end

function Base.show(io::IO, cur::Cursor)
    write(io, "($(cur.line),$(cur.col);$(cur.i))='$(cur.c)'")
end

abstract type ParseError end
struct InvalidNameChar <: ParseError end
struct InvalidTrackerChar <: ParseError end
struct InvalidRefChar <: ParseError end
struct EndOfString <: ParseError end

Base.show(io::IO, ::InvalidNameChar) = write(io, "Invalid character in test name")
Base.show(io::IO, ::InvalidTrackerChar) = write(io, "Invalid character in tracker ID")
Base.show(io::IO, ::InvalidRefChar) = write(io, "Invalid character in bug reference")
Base.show(io::IO, ::EndOfString) = write(io, "Unexpectedly reached the end of the string")

mutable struct ParseContext
    itr::Union{Tuple{Char, Int}, Nothing}
    line::Int
    col::Int
    errors::Array{Tuple{ParseError, Union{Cursor, Nothing}}}
end

function ParseContext(text::String)::ParseContext
    ParseContext(iterate(text), 1, 1,
                 Tuple{String, Union{Cursor, Nothing}}[])
end

function Base.show(io::IO, ctx::ParseContext)
    write(io, "ParseContext { ($(ctx.col), $(ctx.line)), errors: [")
    for (e, loc) in ctx.errors
        write(io, "\n\t$loc: $e")
    end
    write(io, "]}")
end

function iterate!(text::String, ctx::ParseContext)
    ctx.itr = iterate(text, ctx.itr[2])
    if ctx.itr !== nothing
        (c, _) = ctx.itr
        if c === '\n'
            ctx.line += 1
            ctx.col = 1
        else
            ctx.col += 1
        end
    end
end

function pusherr!(ctx::ParseContext, err::ParseError)
    e = if ctx.itr !== nothing
        (err, Cursor(ctx.line, ctx.col, ctx.itr...))
    else
        (err, nothing)
    end

    if length(ctx.errors) < 10
        push!(ctx.errors, e)
    end
end

macro pusherr(ctx, err, cond)
    err = isa(err, QuoteNode) ? err.value : err

    esc(:(if $cond
          pusherr!($ctx, $err())
          return nothing
      end))
end

macro pusherr(ctx, err)
    err = isa(err, QuoteNode) ? err.value : err

    esc(:(pusherr!($ctx, $err()); return nothing))
end

function parse_name!(text, ctx::ParseContext)::Union{String, Nothing}
    name = Char[]

    while ctx.itr !== nothing
        (c, i) = ctx.itr
        @match c begin
            'A':'z' || '0':'9' || '-' || '_' => push!(name, c)
            ',' || ':' => return String(name)
            _ => @pusherr(ctx, :InvalidNameChar)
        end
        iterate!(text, ctx)
    end

    String(name)
end

function parse_bugref!(text, ctx::ParseContext; tracker=true)::Union{String, Nothing}
    ref = Char[]

    while tracker
        @pusherr(ctx, :EndOfString, ctx.itr === nothing)
        (c, i) = ctx.itr

        @match c begin
            'A':'z' => push!(ref, c)
            '#' => begin
                @pusherr(ctx, :InvalidTrackerChar, length(ref) < 1)
                push!(ref, c)
                tracker = false
            end
            _ => @pusherr(ctx, :InvalidTrackerChar)
        end

        iterate!(text, ctx)
    end

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        cont = @match c begin
            '0':'9' || 'A':'z' => push!(ref, c); true
            _ => false
        end

        cont ? iterate!(text, ctx) : break
    end

    @pusherr(ctx, :EndOfString, length(ref) < 1)

    String(ref)
end

function parse_name_or_bugref!(text, ctx::ParseContext)::Union{String, Nothing}
    buf = Char[]
    rest = nothing

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        cont = @match c begin
            'A':'z' => push!(buf, c); true
            '#' => (rest = parse_bugref!(text, ctx); false)
            _ => (rest = parse_name!(text, ctx); false)
        end

        cont ? iterate!(text, ctx) : break
    end

    if rest !== nothing
        String(buf) * rest
    else
        nothing
    end
end

"""
Try to extract the test-name:bug-ref pairs from a comment

Syntax:
<test name 1>[, <test name 2>...]: <bug ref 1>[, <bug ref 2>...][, <test name n>...]

"""
function parse_bugref!(spec::Dict{String, Array{String}}, gen::Array{String}, text::String)
    ctx = ParseContext(text)
    curnames::Array{String} = String[]
    currefs::Array{String} = String[]

    while itr !== nothing
        name = parse_name(text, itr)
        if name === nothing
            iterate!(text, ctx)
            continue
        end

        (c, _) = ctx.itr
        @match c begin
            
        end
    end
end

end
