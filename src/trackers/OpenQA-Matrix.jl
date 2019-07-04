import Base.Ordering
import Base.Order
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

    * builds: test results for each build where a result could be found
"""
mutable struct TestSeq
    builds::SortedDict{OrdBuild, TestResult}
end

TestSeq() = TestSeq(SortedDict{OrdBuild, TestResult}())

function equal_for_builds(ts1::TestSeq, ts2::TestSeq, builds::SortedBuilds)
    for b in builds
        hk1, hk2 = haskey(ts1.builds, b), haskey(ts2.builds, b)
        hk1 ≠ hk2 && return false
        hk1 && ts1.builds[b].result ≠ ts2.builds[b].result && return false
    end
    true
end

struct TestSeqGroup
    tests::Vector{TestResult}
    seq::TestSeq
end

mutable struct BuildMatrix
    builds::SortedBuilds
    seqs::SortedDict{TestResult, TestSeq}
end

struct BuildMatrixGrouped
    m::BuildMatrix
    groups::Vector{TestSeqGroup}
end

function filter_seqs(fn::Function, m::BuildMatrix)
    seqs = SortedDict{TestResult, TestSeq}(m.seqs.bt.ord)

    for (t, seq) in m.seqs
        g = Iterators.Generator(m.builds) do b
            haskey(seq.builds, b) ? seq.builds[b] : nothing
        end

        if fn(t, g)
            seqs[t] = seq
        end
    end

    BuildMatrix(m.builds, seqs)
end

function truncate_builds(m::BuildMatrix, n::Int)
    m2 = BuildMatrix(SortedBuilds{Float64}(Iterators.take(m.builds, n),
                                           Order.Reverse),
                     m.seqs)

    filter_seqs(m2) do ex, builds
        !all(builds) do bres
            bres == nothing
        end
    end
end

function filter_builds(fn::Function, m::BuildMatrix)
    builds = SortedBuilds{Float64}(Order.Reverse)

    for b in m.builds
        g = Iterators.Generator(values(m.seqs)) do seq
            haskey(seq.builds, b) ? seq.builds[b] : nothing
        end

        fn(g) && push!(builds, b)
    end

    BuildMatrix(builds, m.seqs)
end

function build_matrix(results,
                      ordering=FieldSubsetOrdering(:suit, :name, :arch,
                                                   :machine, :flags))::BuildMatrix
    builds = SortedBuilds{Float64}(Order.Reverse)
    seqs = SortedDict{TestResult, TestSeq}(ordering)

    # For now we are optimistic about the product and pessimistic about the
    # test environment, so first pick the best test result for each build
    for res::TestResult in results
        build = OrdBuild(Float64, res.build)

        push!(builds, build)

        seq = get!(seqs, res) do
            TestSeq()
        end

        if get!(seq.builds, build, res).result != "passed"
            seq.builds[build] = res
        end
    end

    BuildMatrix(builds, seqs)
end

describe(m::BuildMatrix) = "$(length(m.builds)) builds x $(length(m.seqs)) tests"

function Base.show(io::IO, mime::MIME"text/html", m::BuildMatrix)
    maxrow, maxbuild = if get(io, :limit, true)
        h, w = displaysize()
        min(h, length(m.seqs)), min(max(1, Int(floor(w / 5)) - 5), length(m.builds))
    else
        length(m.seqs), length(m.builds)
    end

    write(io, "<p>BuildMatrix: ",
          repr(length(m.builds)), " builds x ",
          repr(length(m.seqs)), " tests</p>")
    write(io, "<table class=\"build-matrix\">")
    write(io, "<thead><tr>")
    write(io, "<th>Suit</th><th>Name</th><th>Arch</th><th>Machine</th><th>Flags</th>")

    builds = Iterators.take(m.builds, maxbuild)
    for b in builds
        write(io, "<th>", b.orig, "</th>")
    end
    maxbuild < length(m.builds) && write(io, "<th>&hellip;</th>")

    write(io, "</tr></thead><tbody>")

    c = 0
    for (t, seq) in m.seqs
        write(io, "<tr><td>", join(t.suit, ":"), "</td>")
        write(io, "<td>", t.name, "</td><td>", t.arch, "</td><td>", t.machine, "</td>")
        write(io, "<td>", join(t.flags, ":"), "</td>")

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

function group_matrix(issimilar::Function, m::BuildMatrix)::BuildMatrixGrouped
    groups = TestSeqGroup[]
    gtests = nothing
    gseq = nothing

    for (test, seq) in m.seqs
        is_in_cur_group = (gtests ≠ nothing &&
                           equal_for_builds(seq, gseq, m.builds) &&
                           issimilar(test, gtests[end]))

        if is_in_cur_group
            push!(gtests, test)
        else
            if gtests ≠ nothing
                push!(groups, TestSeqGroup(gtests, gseq))
            end

            gtests = TestResult[test]
            gseq = seq
        end
    end

    if gtests ≠ nothing
        push!(groups, TestSeqGroup(gtests, gseq))
    end

    BuildMatrixGrouped(m, groups)
end

function write_test_seq_cells(io::IO, t, seq, builds)
    uri = get_uri(t)

    write(io, "<tr><td style='word-break: break-all'>", join(t.suit, ":"), "</td>")
    write(io, "<td style='word-break: break-all'>", t.name, "</td><td>", t.arch,
          "</td><td style='word-break: break-all'>", t.machine, "</td>")
    write(io, "<td style='word-break: break-all'>", join(t.flags, ":"), "</td>")

    for b in builds
        if haskey(seq.builds, b)
            local t = seq.builds[b]

            print(io, "<td><a href=\"", uri, "\">")
            t.result ≠ "passed" && print(io, "<strong>")
            print(io, t.result)
            t.result ≠ "passed" && print(io, "</strong>")
            print(io, "</a></td>")
        else
            write(io, "<td> _ </td>")
        end
    end
end

function Base.show(io::IO, mime::MIME"text/html", mg::BuildMatrixGrouped)
    m = mg.m
    gs = mg.groups
    maxrow, maxbuild = if get(io, :limit, true)
        h, w = displaysize()
        h, min(max(1, Int(floor(w / 5)) - 5), length(m.builds))
    else
        length(gs), length(m.builds)
    end
    actualrows = 0
    showngroups = 0

    write(io, "<p>BuildMatrixView: ",
          repr(length(m.builds)), " builds x ",
          repr(length(gs)), " test groups (", repr(length(m.seqs)), " tests)</p>")
    write(io, "<table class='build-matrix'>")
    write(io, "<thead><tr>")
    write(io, "<th>Suit</th><th>Name</th><th>Arch</th><th>Machine</th><th>Flags</th>")

    builds = Iterators.take(m.builds, maxbuild)
    for b in builds
        write(io, "<th>", b.orig, "</th>")
    end
    maxbuild < length(m.builds) && write(io, "<th>&hellip;</th>")

    write(io, "</tr></thead><tbody>")

    for g in gs
        seq = g.seq

        t = g.tests[1]
        write_test_seq_cells(io, t, seq, builds)
        maxbuild < length(m.builds) && write(io, "<td>&hellip;</td>")
        write(io, "</tr>")
        actualrows += 1

        if length(g.tests) > 2
            write(io, "<tr>")
            for p in (:suit, :name, :arch, :machine, :flags)
                if all(ot -> getproperty(ot, p) == getproperty(t, p), g.tests)
                    v = getproperty(t, p)

                    if v isa AbstractString
                        write(io, "<td>", v, "</td>")
                    else
                        write(io, "<td>", join(v, ":"), "</td>")
                    end
                else
                    write(io, "<td>&vellip;</td>")
                end
            end

            write(io, "<td colspan='$maxbuild'>",
                  repr(length(g.tests) - 2), " similar tests hidden</td>")
            maxbuild < length(m.builds) && write(io, "<td>&hellip;</td>")
            write(io, "</tr>")
            actualrows += 1
        end

        if length(g.tests) > 1
            t = g.tests[end]
            write_test_seq_cells(io, t, seq, builds)
            maxbuild < length(m.builds) && write(io, "<td>&hellip;</td>")
            write(io, "</tr>")
            actualrows += 1
        end

        showngroups += 1
        if actualrows >= maxrow
            break
        end
    end

    if showngroups < length(gs)
        write(io, "<tr>")
        for _ in 1:(maxbuild + 5)
            write(io, "<td>&vellip;</td>")
        end
        write(io, "</tr>")
    end

    write(io, "</tbody></table>")
end
