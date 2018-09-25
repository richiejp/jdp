module BugRefs

struct Cursor
    line::Int
    col::Int
    c::Char
    i::Int
end

@enum ParseError begin
    InvalidNameChar
    InvalidTrackerChar
    InvalidRefChar
    EndOfString
end

mutable struct ParseContext
    itr::Union{Tuple{Char, Int}, Nothing}
    line::Int
    col::Int
    errors::Array{(ParseError, Union{Cursor, Nothing})}
end

function ParseContext(text::String)::ParseContext
    ParseContext(iterate(text), 1, 1,
                 Tuple{String, Union{Cursor, Nothing}}[])
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

function pusherr!(ctx::ParserContext, err::ParseError)
    e = if ctx.itr !== nothing
        (msg, Cursor(ctx.line, ctx.col, ctx.itr...))
    else
        (msg, nothing)
    end

    if length(ctx.errors) < 10
        push!(ctx.errors, e)
    end
end

macro pusherr(ctx::ParserContext, err::ParseError, cond::Expr)
    :(if $cond
          pusherr!($ctx, $err)
          return nothing
      end)
end
macro pusherr(ctx::ParserContext, err::ParseError)
    @pusherr(ctx, err, true)
end

function parse_name!(text, ctx::ParseContext)::Union{String, Nothing}
    name = Char[]

    while ctx.itr !== nothing
        (c, i) = ctx.itr
        @match c begin
            'a':'Z' || '0':'9' || '-' || '_' => push!(name, c)
            ',' || ':' => return String(name)
            _ => @pusherr(ctx, InvalidNameChar)
        end
        iterate!(text, ctx)
    end
end

function parse_bugref!(text, ctx::ParseContext; tracker=true)::Union{String, Nothing}
    ref = Char[]

    while tracker
        @pusherr(ctx, EndOfString, ctx.itr === nothing)
        (c, i) = ctx.itr

        @match c begin
            'a':'Z' => push!(ref, c)
            '#' => begin
                @pusherr(ctx, InvalidTrackerChar, length(ref) < 1)
                push!(ref, c)
                break
            end
            _ => @pusherr(ctx, InvalidTrackerChar)
        end

        iterate!(text, ctx)
    end

    iterate!(text, ctx)
    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            '0':'9' || 'a':'Z' => push!(ref, c)
            _ => break
        end
    end

    @pusherr(ctx, EndOfString, length(ref) < 1)

    String(ref)
end

function parse_name_or_bugref!(text, ctx::ParseContext)::Union{String, Nothing}
    buf = Char[]
    rest = nothing

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            'a':'Z' => push!(buf, c)
            '#' => (rest = parse_bugref!(text, ctx); break)
            _ => (rest = parse_name!(text, ctx); break)
        end

        iterate!(text, ctx)
    end

    if rest !== nothing
        String(buf) * rest
    else
        nothing
    end
end

"""
Try to extract the test-name:bug-ref pairs from a comment

Possible syntaxes

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
