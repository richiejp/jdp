"""Parser for the Bug references (tags) DSL

See [`parse_comment`](@ref)'s docs for the format.

"""
module BugRefsParser

export tokval, parse_comment

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

"Some kind of symbol or even an expression; so long as it can be represented by SubString"
abstract type AbstractToken end

Base.:(==)(t1::AbstractToken, t2::AbstractToken) = false

struct Token{T} <: AbstractToken
    src::String
    range::UnitRange
end

const Test = Token{:Test}
const Tracker = Token{:Tracker}
const ID = Token{:ID}

"""
    tokval(tok)

Get the textual value of any AbstractToken. 

Implement using SubString and not [n:m] because the former is zero-copy.
"""
function tokval(tok::Token)::SubString{String}
    SubString(tok.src, tok.range)
end

Base.:(==)(t1::Token{T}, t2::Token{T}) where {T} = tokval(t1) == tokval(t2)

const WILDCARD = Test("*", 1:1)

struct Ref <: AbstractToken
    tracker::Tracker
    id::ID
end

function tokval(br::Ref)::SubString{String}
    SubString(br.tracker.src, br.tracker.range.start, br.id.range.stop)
end

Base.:(==)(t1::Ref, t2::Ref) = tokval(t1) == tokval(t2)

function Base.hash(token::AbstractToken, h::UInt)
    hash(tokval(token), h)
end

struct Tagging
    test::Test
    tests::Union{Array{Test}, Nothing}
    ref::Ref
    refs::Union{Array{Ref}, Nothing}

    function Tagging(test::Test,
                     tests::Array{Test},
                     ref::Ref,
                     refs::Array{Ref})
        new(test,
            length(tests) > 0 ? copy(tests) : nothing,
            ref,
            length(refs) > 0 ? copy(refs) : nothing)
    end

    function Tagging(test::Test, ref::Ref)
        new(test, nothing, ref, nothing)
    end
end

function all_refs(t::Tagging)::Array{Ref}
    if t.refs != nothing
        vcat(t.refs, t.ref)
    else
        [t.ref]
    end
end

abstract type ParseError end
struct InvalidNameChar <: ParseError end
struct InvalidTrackerChar <: ParseError end
struct InvalidRefChar <: ParseError end
struct ExpectedPunct <: ParseError end
struct OnlyFoundName <: ParseError end
struct EndOfString <: ParseError end
struct ZeroLengthID <: ParseError end

Base.show(io::IO, ::InvalidNameChar) = write(io, "Invalid character in test name")
Base.show(io::IO, ::InvalidTrackerChar) = write(io, "Invalid character in tracker ID")
Base.show(io::IO, ::InvalidRefChar) = write(io, "Invalid character in bug reference")
Base.show(io::IO, ::ExpectedPunct) = write(io, "Expected ',' or ':'")
Base.show(io::IO, ::OnlyFoundName) = write(io, "Expected Bugref, but only found name")
Base.show(io::IO, ::EndOfString) = write(io, "Unexpectedly reached the end of the string")
Base.show(io::IO, ::ZeroLengthID) = write(io, "Expected a bug ID after '#'")

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

    ctx.itr
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
                     prestart::Union{Int, Nothing}=nothing)::Union{Test, Nothing}
    (_, i) = ctx.itr
    start = prestart !== nothing ? prestart : i - 1
    
    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            'A':'z' || '0':'9' || '-' || '_' || '*' => nothing
            ',' || ':' || ' ' => begin
                @pusherr(ctx, :InvalidNameChar, i - start < 2)
                return Test(text, start:(i - 2))
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

function parse_ref!(text::String, ctx::ParseContext)::Union{ID, Nothing}
    (c, i) = ctx.itr
    start = i - 1

    if c === '#'
        iterate!(text, ctx)
        start += 1
    end

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        if !('A' <= c <= 'z' || '0' <= c <= '9')
            break
        end

        iterate!(text, ctx)
    end

    @pusherr(ctx, :ZeroLengthID, i - start < 2)
    if ctx.itr !== nothing
        ID(text, start:(i - 2))
    else
        ID(text, start:(i - 1))
    end
end

function parse_bugref!(text::String, ctx::ParseContext)::Union{Ref, Nothing}
    t = parse_tracker!(text, ctx)

    if t !== nothing
        r = parse_ref!(text, ctx)

        if r !== nothing
            return Ref(t, r)
        end
    end

    nothing
end

function parse_name_or_bugref!(text::String,
                               ctx::ParseContext)::Union{Test, Ref, Nothing}
    (_, i) = ctx.itr
    start = i - 1

    while ctx.itr !== nothing
        (c, i) = ctx.itr

        @match c begin
            'A':'z' => iterate!(text, ctx)
            '#' => begin
                @pusherr(ctx, InvalidTrackerChar, i - start < 2)
                tracker = Tracker(text, start:(i - 2))
                ref = parse_ref!(text, ctx)
                if ref !== nothing
                    return Ref(tracker, ref)
                else
                    return nothing
                end
            end
            _ => return parse_name!(text, ctx; prestart=start)
        end
    end
end

function chomp!(text::String, ctx::ParseContext)
    while ctx.itr !== nothing
        (c, i) = ctx.itr

        if c !== ' ' && c !== '\t'
            break
        end

        iterate!(text, ctx)
    end
end

"""
    parse_comment(text)

Try to extract the test-name:bug-ref pairs from a comment

Below is the approximate syntax in EBNF. Assume letter ∈ [a-Z] and digit ∈
[0-9] and whitespace is allowed between testnames, bugrefs, ':' and ',':

```
testname = letter | digit { letter | digit | '_' | '-' }
tracker = letter { letter }
id = letter | digit { letter | digit }
bugref = tracker '#' id
tagging = testname {',' testname} ':' bugref {',' bugref}
taggings = tagging { tagging }
```

A tagging can assign many bug references to many testnames, which means you
can have something like: test1, test2: bsc#1234, git#a33f4. Which tags tests 1
and 2 with both bug references.

Comments many contain many taggings along with other random text. If the
algorithm finds an error it discards the current tagging and starts trying to
parse a new tagging from the point where it failed.

"""
function parse_comment(text::String)::Tuple{Array{Tagging}, ParseContext}
    ctx = ParseContext(text)
    names = Test[]
    refs = Ref[]
    taggings = Tagging[]

    chomp!(text, ctx)
    while ctx.itr !== nothing
        name = parse_name_or_bugref!(text, ctx)
        if name === nothing
            if ctx.itr !== nothing
                iterate!(text, ctx)
            end
            continue
        end

        # If the user supplies a naked Ref, we assume they just want to tag
        # every test failure with that Ref
        if isa(name, Ref)
            push!(taggings, Tagging(WILDCARD, name))
        end

        @label NAME_LIST
        chomp!(text, ctx)

        restart = false
        # If we get a comma after a valid test name then this might be a
        # many-to-one or many-to-many tagging. So try to parse a list of test
        # names.
        while ctx.itr !== nothing && ctx.itr[1] === ','
            iterate!(text, ctx)
            chomp!(text, ctx)
            name2 = parse_name_or_bugref!(text, ctx)
            if name2 === nothing
                restart = true
                break
            end

            # Again not clear what user wanted because we have not seen ':'
            # yet, so discard the name list and just tag everything with the
            # bug ref
            if isa(name2, Ref)
                push!(taggings, Tagging(WILDCARD, name2))
                restart = true
                break
            end

            push!(names, name2)
            chomp!(text, ctx)
        end

        if ctx.itr === nothing
            pusherr!(ctx, EndOfString())
            break
        end

        if restart
            empty!(names)
            continue
        end

        # We expect a bug ref after ':'
        if ctx.itr[1] !== ':'
            pusherr!(ctx, ExpectedPunct())
            empty!(names)
            continue
        end

        iterate!(text, ctx)
        if ctx.itr === nothing
            pusherr!(ctx, EndOfString())
            break
        end

        chomp!(text, ctx)
        thing = parse_name_or_bugref!(text, ctx)

        # Handle scenario where user writes "Some non-bugref text: testname:poo#123"
        if isa(thing, Test)
            pusherr!(ctx, OnlyFoundName())
            empty!(names)
            name = thing
            @goto NAME_LIST
        end

        if thing === nothing
            empty!(names)
            if ctx.itr !== nothing
                iterate!(text, ctx)
            end
            chomp!(text, ctx)
            continue
        end

        ref = thing

        chomp!(text, ctx)
        # So we found one bugref and have a valid tagging already, but there
        # may be more bugrefs for this tagging.
        while ctx.itr !== nothing && ctx.itr[1] === ','
            iterate!(text, ctx)
            chomp!(text, ctx)
            if ctx.itr === nothing
                break
            end

            thing = parse_name_or_bugref!(text, ctx)
            if thing === nothing
                break
            end

            # We may have started parsing a new tagging, so save this one and
            # jump back
            if isa(thing, Test)
                push!(taggings, Tagging(name, names, ref, refs))
                empty!(names)
                empty!(refs)
                name = thing
                @goto NAME_LIST
            end

            push!(refs, thing)
            chomp!(text, ctx)
        end

        push!(taggings, Tagging(name, names, ref, refs))
        empty!(names)
        empty!(refs)
        chomp!(text, ctx)
    end

    taggings, ctx
end

end
