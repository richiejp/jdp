"""Bug references are usually a three letter abreviation (TLA) for a tracker
instance (e.g. bugzilla.suse.com -> bsc) followed by a `#` and then an id
number, so for example `bsc#12345`.

Test failures can be 'tagged' with a bug reference. This usually looks
something like `test01:bsc#12345`.

This module provides methods for processing bug references and tags which are
typically included in a comment on a test failure, but can be taken from any
text.
"""
module BugRefs

using JDP.Trackers

import ..BugRefsParser
import ..BugRefsParser: tokval

WILDCARD = String(tokval(BugRefsParser.WILDCARD))

export BugRef, Tags, extract_refs, extract_tags!, get_refs

const ID = String

struct Ref
    tracker::Tracker
    id::ID
end

Ref(pref::BugRefsParser.Ref, trackers::TrackerRepo)::Ref =
    Ref(get_tracker(trackers, tokval(pref.tracker)), ID(tokval(pref.id)))

Ref(sref::String, trackers::TrackerRepo)::Ref =
    Ref(BugRefsParser.parse_bugref(sref), trackers)

Base.:(==)(r::Ref, ro::Ref) = r.tracker == ro.tracker && r.id == ro.id

Base.show(io::IO, ::MIME"text/plain", ref::Ref) =
    write(io, ref.tracker.tla, "#", ref.id)

Base.show(io::IO, ref::Ref) = show(io, MIME("text/plain"), ref)

function Base.show(io::IO, ::MIME"text/html", ref::Ref)
    if ref.tracker.host == nothing
        return show(io, ref)
    end

    write(io, "<a href=\"")
    if ref.tracker.api == nothing
        write(io, host)
    else
        Trackers.write_get_item_html_url(io, ref.tracker, ref.id)
    end
    write(io, "\">"); show(io, ref); write(io, "</a>")
end

function Base.show(io::IO, ::MIME"text/markdown", ref::Ref)
    if ref.tracker.host == nothing
        return show(io, ref)
    end

    write(io, "["); show(io, ref); write(io, "](")
    if ref.tracker.api == nothing
        write(io, host)
    else
        Trackers.write_get_item_html_url(io, ref.tracker, ref.id)
    end
    write(io, ")")
end

Base.show(io::IO, ::MIME"text/html", refs::Vector{Ref}) = foreach(refs) do ref
    show(io, MIME("text/html"), ref)
    write(io, "&nbsp;")
end

Base.show(io::IO, ::MIME"text/markdown", refs::Vector{Ref}) = foreach(refs) do ref
    show(io, MIME("text/markdown"), ref)
    write(io, " ")
end

const Tags = Dict{String, Array{Ref}}

function get_refs(tags::Tags, name::String)::Vector{Ref}
    refs = Vector{Ref}()

    if haskey(tags, name)
        append!(refs, tags[name])
    end

    refs
end

function extract_refs(text::String, trackers::TrackerRepo)::Array{Ref}
    (tags, _) = BugRefsParser.parse_comment(text)
    refs = Ref[]

    for tag = tags, ref = tag.refs
        push!(refs, Ref(ref, trackers))
    end

    refs
end

function extract_tags!(index::Tags, text::String, trackers::TrackerRepo)::Tags
    (tags, _) = BugRefsParser.parse_comment(text)

    for tag = tags, test = tag.tests
        refs = get!(() -> [], index, replace(tokval(test), "/" => "-"))
        append!(refs, map(pref -> Ref(pref, trackers), tag.refs))
    end

    index
end

end #module
