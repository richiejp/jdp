"""Bug references are usually a three letter abreviation (TLA) for a tracker
instance (e.g. bugzilla.suse.com -> bsc) followed by a `#` and then an id
number, so for example `bsc#12345`.

Test failures can be 'tagged' with a bug reference. This usually looks
something like `test01:bsc#12345`. There are also anti-tags which signal that
a failure should no longer be associated with a given bug. These look like
`test01:!bsc#12345`.

This module provides methods for processing bug references and tags which are
typically included in a comment on a test failure, but can be taken from any
text.
"""
module BugRefs

using JDP.Tracker

import ..BugRefsParser
import ..BugRefsParser: tokval

WILDCARD = String(tokval(BugRefsParser.WILDCARD))

export BugRef, Tags, extract_tags!, get_refs

const ID = String

"A reference to a bug on a particular tracker"
struct Ref
    tracker::(Tracker.Instance)
    id::ID
    negated::Bool
    propagated::Bool
    advisory::Bool
end

Ref(pref::BugRefsParser.Ref, trackers::TrackerRepo, negated::Bool, propagated::Bool)::Ref =
    Ref(get_tracker(trackers, tokval(pref.tracker)),
        ID(tokval(pref.id)), negated, propagated, pref.tracker.quoted)

Ref(sref::String, trackers::TrackerRepo, negated=false, propagated=false)::Ref =
    Ref(BugRefsParser.parse_bugref(sref), trackers, negated, propagated)

Base.:(==)(r::Ref, ro::Ref) =
    r.tracker == ro.tracker && r.id == ro.id &&
    r.negated == ro.negated && r.propagated == ro.propagated &&
    r.advisory == ro.advisory

Base.hash(r::Ref, h::UInt) =
    hash(r.tracker, hash(r.id, hash(r.negated, hash(r.propagated, hash(r.advisory, h)))))

Base.show(io::IO, ::MIME"text/plain", ref::Ref) = if ref.negated
    write(io, "!", ref.tracker.tla, ref.advisory ? "@" : "#", ref.id)
else
    write(io, ref.tracker.tla, ref.advisory ? "@" : "#", ref.id)
end

Base.show(io::IO, ref::Ref) = show(io, MIME("text/plain"), ref)

function Base.show(io::IO, ::MIME"text/html", ref::Ref)
    if ref.tracker.host == nothing
        return show(io, ref)
    end

    if ref.negated
        write(io, "<b>!</b>")
    end
    write(io, "<a href=\"")
    if ref.tracker.api == nothing
        write(io, host)
    else
        Tracker.write_get_item_html_url(io, ref.tracker, ref.id)
    end
    write(io, "\">")
    write(io, ref.tracker.tla, ref.advisory ? "@" : "#", ref.id)
    write(io, "</a>")
end

function Base.show(io::IO, ::MIME"text/markdown", ref::Ref)
    if ref.tracker.host == nothing
        return show(io, ref)
    end

    if ref.negated
        write(io, "**!**")
    end
    write(io, "[")
    write(io, ref.tracker.tla, ref.advisory ? "@" : "#", ref.id)
    write(io, "](")
    if ref.tracker.api == nothing
        write(io, host)
    else
        Tracker.write_get_item_html_url(io, ref.tracker, ref.id)
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

"Parse some text for Bug tags and add them to the given tags index"
function extract_tags!(index::Tags, text::String, trackers::TrackerRepo)::Tags
    (tags, _) = BugRefsParser.parse_comment(text)

    for tag = tags, test = tag.tests
        refs = get!(() -> [], index, replace(tokval(test), "/" => "-"))
        append!(refs, map(tag.refs) do pref
            Ref(pref, trackers, tag.negated, test.quoted)
        end)
    end

    index
end

end #module
