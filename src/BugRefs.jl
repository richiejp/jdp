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

using Match
using Markdown: MD, Link, Paragraph, LineBreak

using JDP.Trackers

import ..BugRefsParser
import ..BugRefsParser: tokval

WILDCARD = String(tokval(BugRefsParser.WILDCARD))

export BugRef, Tags, extract_refs, extract_tags!, get_refs

function get_uris(t::Tracker, ids::Array{Int64})::Array{String}
    map(id -> get_uri(t, id), ids)
end

function get_uris_md(t::Tracker, ids::Array{Int64})::MD
    uris = get_uris(t, ids)
    md = Any[]

    for (id, uri) in zip(ids, uris)
        push!(md, Link("$(get_tla(t))#$id", uri), " ")
    end

    MD(Paragraph(md))
end

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

function Base.show(io::IO, ::MIME"text/plain", ref::Ref)
    write(io, ref.tracker.tla, "#", ref.id)
end

function Base.show(io::IO, ::MIME"text/html", ref::Ref)
    @match (ref.tracker.host, ref.tracker.api) begin
        (nothing, _) => Base.show(io, MIME("text/plain"), ref)
        (host, nothing) => begin
            write(io, "<a href=\"", host, "\">")
            show(io, MIME("text/plain"), ref)
            write(io, "</a>")
        end
        (host, api) => begin
            write(io, "<a href=\"")
            Trackers.write_get_bug_html_url(io, ref.tracker, ref.id)
            write(io, "\">")
            show(io, MIME("text/plain"), ref)
            write(io, "</a>")
        end
    end
end

function to_md_link(ref::Ref)::Link
    Link(get_tla(ref.tracker) * "#" * ref.id,
         get_uri(ref.tracker, parse(Int64, ref.id)))
end

function to_md(refs::Array{Ref})::MD
    md = Any[]

    for ref in refs
        push!(md, to_md_link(ref), LineBreak())
    end

    MD(Paragraph(md))
end

const Tags = Dict{String, Array{Ref}}

function get_refs(tags::Tags, name::String)::Array{Ref}
    refs = Ref[]

    haskey(tags, WILDCARD) && append!(refs, tags[WILDCARD])
    haskey(tags, name) && append!(refs, tags[name])

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
