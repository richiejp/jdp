import Base.Ordering
import Base.lt
import DataStructures.eq

struct OrdBuild{T}
    orig::String
    val::T
end

OrdBuild(::Type{Float64}, orig) = OrdBuild(orig, parse(Float64, orig))

Base.isless(b1::OrdBuild{T}, b2::OrdBuild{T}) where {T} =
    isless(b1.val, b2.val)

Base.isequal(b1::OrdBuild{T}, b2::OrdBuild{T}) where {T} =
    isequal(b1.val, b2.val)

const SortedBuilds{T} = SortedSet{OrdBuild{T}}

struct FieldSubsetOrdering{N} <: Ordering
    fields::NTuple{N, Symbol}

    FieldSubsetOrdering(fields...) = new{length(fields)}(fields)
end

function lt(o::FieldSubsetOrdering, a, b)
    for p in o.fields
        getproperty(a, p) < getproperty(b, p) && return true
        getproperty(a, p) ≠ getproperty(b, p) && return false
    end
    false
end

eq(o::FieldSubsetOrdering, a, b) = all(o.fields) do p
    getproperty(a, p) == getproperty(b, p)
end

"""Test Sequence - A row in the diff matrix

    * exemplar: An arbitrary test result which all other results in the sequence
                will be similar to
    * seq: A test result for each build or Nothing if a result could not be
           found for a build
"""
mutable struct TestSeq
    ex::TestResult
    builds::SortedDict{OrdBuild, TestResult}
end

TestSeq(test::TestResult) =
    TestSeq(test, SortedDict{OrdBuild, Union{TestResult, Nothing}}())

mutable struct TestSeqGroup
    degenerate::Bool
    seqs::SortedDict{TestResult, TestSeq}
end

Base.isless(t1::TestSeqGroup, t2::TestSeqGroup) =
    isless(first(t1.seqs), first(t2.seqs))

Base.isequal(t1::TestSeqGroup, t2::TestSeqGroup) =
    isequal(first(t1.seqs), first(t2.seqs))

mutable struct BuildMatrix
    builds::SortedBuilds
    rows::SortedDict{TestResult, TestSeq}
end

function filter_rows(fn::Function, m::BuildMatrix)
    BuildMatrix(m.builds, filter(fn, m.rows))
end

function build_matrix(results)::BuildMatrix
    builds = SortedBuilds{Float64}(Base.Order.Reverse)
    seqs = SortedDict{TestResult, TestSeq}(
        FieldSubsetOrdering(:suit, :name, :arch, :machine, :flags))

    # For now we are optimistic about the product and pessimistic about the
    # test environment, so first pick the best test result for each build
    for res::TestResult in results
        build = OrdBuild(Float64, res.build)

        push!(builds, build)

        seq = get!(seqs, res) do
            TestSeq(res)
        end

        if get!(seq.builds, build, res).result != "passed"
            seq.builds[build] = res
        end
    end

    BuildMatrix(builds, seqs)
end

function Base.show(io::IO, mime::MIME"text/html", m::BuildMatrix)
    maxrow, maxbuild = if get(io, :limit, true)
        h, w = displaysize(io)
        min(h, length(m.rows)), min(max(1, Int(floor(w / 5)) - 5), length(m.builds))
    else
        length(m.rows), length(m.builds)
    end

    write(io, "<table class=\"build-matrix\">")
    write(io, "<thead><tr>")
    write(io, "<th>Suit</th><th>Test</th><th>Arch</th><th>Machine</th><th>Flags</th>")

    builds = Iterators.take(m.builds, maxbuild)
    for b in builds
        write(io, "<th>", b.orig, "</th>")
    end
    maxbuild < length(m.builds) && write(io, "<th>&hellip;</th>")

    write(io, "</tr></thead><tbody>")

    c = 0
    for (t, seq) in m.rows
        write(io, "<tr><td>", join(t.suit, ":"), "</td>")
        write(io, "<td>", t.name, "</td><td>", t.arch, "</td><td>", t.machine, "</td>")
        write(io, "<td>", join(t.flags, ","), "</td>")

        for b in builds
            if haskey(seq.builds, b)
                write(io, "<td>", seq.builds[b].result, "</td>")
            else
                write(io, "<td> _ </td>")
            end
        end
        maxbuild < length(m.builds) && write(io, "<td>&hellip;</td>")

        write(io, "</tr>")

        c += 1
        c > maxrow && break
    end

    if c > maxrow
        write(io, "<tr>")
        for _ in 1:(maxbuild + 5)
            write(io, "<td>&vellip;</td>")
        end
        write(io, "</tr>")
    end

    write(io, "</tbody></table>")
end
