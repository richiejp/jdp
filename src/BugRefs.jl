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

using Markdown: MD, Link, Paragraph, LineBreak

import ..BugRefsParser
import ..BugRefsParser: tokval

export extract_refs

abstract type Tracker end

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

abstract type Bugzilla <: Tracker end
struct Bsc <: Bugzilla end

bsc = Bsc()
Tracker(::Val{:bsc}) = bsc
get_uri(::Bsc, id::Int64) = "https://bugzilla.suse.com/show_bug.cgi?id=$id"
get_tla(::Bsc) = "bsc"

struct Poo <: Tracker end
poo = Poo()
Tracker(::Val{:poo}) = poo
get_uri(::Poo, id::Int64) = "https://progress.opensuse.org/issues/$id"
get_tla(::Poo) = "poo"

const ID = String

struct Ref
    tracker::Tracker
    id::ID
end

function Ref(ref::BugRefsParser.Ref)::Ref
    Ref(Tracker(Val(Symbol(tokval(ref.tracker)))),
        ID(tokval(ref.id)))
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

function extract_refs(text::String)::Array{Ref}
    (tags, _) = BugRefsParser.parse_comment(text)
    refs = Ref[]

    for tag = tags, ref = BugRefsParser.all_refs(tag)
        push!(refs, Ref(ref))
    end

    refs
end

end #module
