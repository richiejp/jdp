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

struct Tagging
    test::TestName
    tests::Union{Array{TestName}, Nothing}
    ref::BugRef
    refs::Union{Array{BugRef}, Nothing}

    function Tagging(test::TestName,
                     tests::Array{TestName},
                     ref::BugRef,
                     refs::Array{BugRef})
        new(test,
            length(tests) > 0 ? copy(tests) : nothing,
            ref,
            length(refs) > 0 ? copy(refs) : nothing)
    end
end


abstract type ParseError end
struct InvalidNameChar <: ParseError end
struct InvalidTrackerChar <: ParseError end
struct InvalidRefChar <: ParseError end
struct ExpectedPunct <: ParseError end
struct OnlyFoundName <: ParseError end
struct EndOfString <: ParseError end
struct ZeroLengthRef <: ParseError end

Base.show(io::IO, ::InvalidNameChar) = write(io, "Invalid character in test name")
Base.show(io::IO, ::InvalidTrackerChar) = write(io, "Invalid character in tracker ID")
Base.show(io::IO, ::InvalidRefChar) = write(io, "Invalid character in bug reference")
Base.show(io::IO, ::ExpectedPunct) = write(io, "Expected ',' or ':'")
Base.show(io::IO, ::OnlyFoundName) = write(io, "Expected Bugref, but only found name")
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

        if !('A' <= c <= 'z' || '0' <= c <= '9')
            break
        end

        iterate!(text, ctx)
    end

    @pusherr(ctx, :ZeroLengthRef, i - start < 2)
    if ctx.itr !== nothing
        Reference(text, start:(i - 2))
    else
        Reference(text, start:(i - 1))
    end
end

function parse_bugref!(text::String, ctx::ParseContext)::Union{BugRef, Nothing}
    t = parse_tracker!(text, ctx)

    if t !== nothing
        r = parse_ref!(text, ctx)

        if r !== nothing
            return BugRef(t, r)
        end
    end

    nothing
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
                @pusherr(ctx, InvalidTrackerChar, i - start < 2)
                tracker = Tracker(text, start:(i - 1))
                ref = parse_ref!(text, ctx)
                if ref !== nothing
                    return BugRef(tracker, ref)
                end

                # If parsing the ref failed start trying to parse something
                # again from the point where we failed
                if ctx.itr !== nothing
                    start = ctx.itr[2] - 1
                end
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
                if ctx.itr !== nothing
                    start = ctx.itr[2]
                    iterate!(text, ctx)
                end
             end
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
Try to extract the test-name:bug-ref pairs from a comment

Below is the approximate syntax in EBNF. Assume letter ∈ [a-Z] and digit ∈
[0-9] and whitespace is allowed between testnames, bugrefs, ':' and ',':

testname = letter | digit { letter | digit | '_' | '-' }
tracker = letter { letter }
reference = letter | digit { letter | digit }
bugref = tracker '#' reference
tagging = testname {',' testname} ':' bugref {',' bugref}
taggings = tagging { tagging }

So a tagging can assign many bug references to many testnames, which means you
can have something like: test1, test2: bsc#1234, git#a33f4. Which tags tests 1
and 2 with both bug references.

Comments many contain many taggings along with other random text. If the
algorithm finds an error it discards the current tagging and starts trying to
parse a new tagging from the point where it failed.

"""
function parse_comment(text::String)::Tuple{Array{Tagging}, ParseContext}
    ctx = ParseContext(text)
    names = TestName[]
    refs = BugRef[]
    taggings = Tagging[]

    chomp!(text, ctx)
    while ctx.itr !== nothing
        name = parse_name!(text, ctx)
        if name === nothing
            iterate!(text, ctx)
            continue
        end

        @label NAME_LIST
        chomp!(text, ctx)

        restart = false
        while ctx.itr !== nothing && ctx.itr[1] === ','
            iterate!(text, ctx)
            chomp!(text, ctx)
            name2 = parse_name!(text, ctx)
            if name2 === nothing
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
        if isa(thing, TestName)
            pusherr!(ctx, OnlyFoundName)
            empty!(names)
            name = thing
            @goto NAME_LIST
        end

        if thing === nothing
            empty!(names)
            iterate!(text, ctx)
            chomp!(text, ctx)
            continue
        end

        ref = thing

        chomp!(text, ctx)
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
            if isa(thing, TestName)
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
