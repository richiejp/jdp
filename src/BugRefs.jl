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

abstract type AbstractToken end

struct Token{T} <: AbstractToken
    src::String
    range::UnitRange
end

const TestName = Token{:TestName}
const Tracker = Token{:Tracker}
const Reference = Token{:Reference}

function tokval(tok::Token)
    tok.src[tok.range]
end

struct BugRef <: AbstractToken
    tracker::Tracker
    reference::Reference
end

function tokval(br::BugRef)
    br.tracker.src[br.tracker.range.start:br.reference.range.stop]
end

abstract type ParseError end
struct InvalidNameChar <: ParseError end
struct InvalidTrackerChar <: ParseError end
struct InvalidRefChar <: ParseError end
struct EndOfString <: ParseError end
struct ZeroLengthRef <: ParseError end

Base.show(io::IO, ::InvalidNameChar) = write(io, "Invalid character in test name")
Base.show(io::IO, ::InvalidTrackerChar) = write(io, "Invalid character in tracker ID")
Base.show(io::IO, ::InvalidRefChar) = write(io, "Invalid character in bug reference")
Base.show(io::IO, ::EndOfString) = write(io, "Unexpectedly reached the end of the string")
Base.show(io::IO, ::ZeroLengthRef) = write(io, "Expected a bug reference after '#'")

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
        if loc !== nothing
            write(io, "\n\t$loc: $e")
        else
            write(io, "\n\tN/A: $e")
        end
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

function parse_name!(text::String, ctx::ParseContext;
                     prestart::Union{Int, Nothing}=nothing)::Union{TestName, Nothing}
    (_, i) = ctx.itr
    start = prestart !== nothing ? prestart : i - 1
    
    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            'A':'z' || '0':'9' || '-' || '_' => nothing
            ',' || ':' || ' ' => begin
                @pusherr(ctx, :InvalidNameChar, i - start < 2)
                return TestName(text, start:(i - 2))
            end
            _ => @pusherr(ctx, :InvalidNameChar)
        end

        iterate!(text, ctx)
    end

    @pusherr(ctx, :EndOfString)
end

function parse_tracker!(text::String, ctx::ParseContext)::Union{Tracker, Nothing}
    (_, i) = ctx.itr
    start = i - 1

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            'A':'z' => nothing
            '#' => begin
                @pusherr(ctx, :InvalidTrackerChar, i - start < 2)
                return Tracker(text, start:(i - 2))
            end
            _ => @pusherr(ctx, :InvalidTrackerChar)
        end

        iterate!(text, ctx)
    end

    @pusherr(ctx, :EndOfString)
end

function parse_ref!(text::String, ctx::ParseContext)::Union{Reference, Nothing}
    (c, i) = ctx.itr
    start = i - 1

    if c === '#'
        iterate!(text, ctx)
        start += 1
    end

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            '0':'9' || 'A':'z' => iterate!(text, ctx)
            _ => :break
        end
    end

    @pusherr(ctx, :ZeroLengthRef, i - start < 2)
    return Reference(text, start:(i - 1))
end

function parse_name_or_bugref!(text::String,
                               ctx::ParseContext)::Union{TestName, BugRef, Nothing}
    (_, i) = ctx.itr
    start = i - 1

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            'A':'z' => iterate!(text, ctx)
            '#' => begin
                tracker = Tracker(text, start:(i - 1))
                ref = parse_ref!(text, ctx)
                if ref !== nothing
                    return BugRef(tracker, ref)
                end

                # If parsing the ref failed start trying to parse something
                # again from the point where we failed
                start = ctx.itr[2] - 1
            end
            _ => begin
                name = parse_name!(text, ctx; prestart=start)
                if name !== nothing
                    return name
                end

                # If parsing the name failed start trying to parse again from
                # just after the point where we failed because the character
                # which caused the failure won't be valid as the first
                # character in a name or tracker
                start = ctx.itr[2]
                iterate!(text, ctx)
             end
        end
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
