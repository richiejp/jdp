struct OrdBuild{T}
    orig::String
    val::T
end

OrdBuild(::Type{Float64}, orig) = OrdBuild(orig, parse(Float64, orig))

Base.isless(b1::OrdBuild{T}, b2::OrdBuild{T}) where {T} =
    isless(b1.val, b2.val)

Base.isequal(b1::OrdBuild{T}, b2::OrdBuild{T}) where {T} =
    b1.val == b2.val

const SortedBuilds{T} = SortedSet{OrdBuild{T}}

"A test wrapper for helping to group similar test results"
struct ExemplarTest
    val::TestResult
end

function Base.isless(t1::ExemplarTest, t2::ExemplarTest)
    e1, e2 = t1.val, t2.val

    ret = all((:suit, :name, :arch, :machine)) do p
        isless(getproperty(e1, p), getproperty(e2, p))
    end
    ret && all(a -> isless(a...), zip(e1.flags, e2.flags))
end

function Base.isequal(t1::ExemplarTest, t2::ExemplarTest)
    e1, e2 = t1.val, t2.val

    ret = all((:suit, :name, :arch, :machine, :flags)) do p
        isequal(getproperty(e1, p), getproperty(e2, p))
    end
end

"""Test Sequence - A row in the diff matrix

    * exemplar: An arbitrary test result which all other results in the sequence
                will be similar to
    * seq: A test result for each build or Nothing if a result could not be
           found for a build
"""
mutable struct TestSeq
    ex::ExemplarTest
    builds::SortedDict{OrdBuild, Union{TestResult, Nothing}}
end

TestSeq(test::TestResult) =
    TestSeq(ExemplarTest(test), SortedDict{OrdBuild, Union{TestResult, Nothing}}())

mutable struct TestSeqGroup
    degenerate::Bool
    seqs::SortedDict{ExemplarTest, TestSeq}
end

Base.isless(t1::TestSeqGroup, t2::TestSeqGroup) =
    isless(first(t1.seqs), first(t2.seqs))

Base.isequal(t1::TestSeqGroup, t2::TestSeqGroup) =
    isequal(first(t1.seqs), first(t2.seqs))

mutable struct BuildMatrix
    builds::SortedBuilds
    rows::SortedDict{ExemplarTest, TestSeq}
end

function build_matrix(results)::BuildMatrix
    builds = SortedBuilds{Float64}()
    seqs = SortedDict{ExemplarTest, TestSeq}()

    # For now we are optimistic about the product and pessimistic about the
    # test environment, so first pick the best test result for each build
    for res::TestResult in results
        build = OrdBuild(Float64, res.build)

        push!(builds, build)

        seq = get!(seqs, ExemplarTest(res)) do
            TestSeq(res)
        end

        if get!(seq.builds, build, res).result != "passed"
            seq.builds[build] = res
        end
    end

    BuildMatrix(builds, seqs)
end
