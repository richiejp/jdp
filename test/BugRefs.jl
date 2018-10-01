using JDP.BugRefs

testname1 = "a_Test-name12"
testname2 = "mmap07"
testname3 = "btrfs_0209"
bugref1 = "bsc#1984"
bugref2 = "git#abcdef1234567890"
text_simple = "$testname1:$bugref1"
text_messy = "Some jibba jabba before a bugref. $testname1: $bugref1"
many_to_many = "$testname2, $testname3 : $bugref1, $bugref2"
many_spaces = "$testname2 , $testname3 : $bugref1 , $bugref2"
many_to_many2 = "$testname1, $testname2, $testname3: $bugref1, $testname2: $bugref2"
naked_bugrefs = "$bugref1, $bugref2"

print_errors(ctx::BugRefs.ParseContext) = if length(ctx.errors) > 0
    println("Parser errors: $ctx")
end

@testset "Bug Reference parsing" begin
    ctx = BugRefs.ParseContext("$testname1 ")
    res = BugRefs.parse_name!("$testname1 ", ctx)
    print_errors(ctx)
    @test length(ctx.errors) < 1
    @test ctx.line == 1 && ctx.col == length(testname1) + 1
    @test BugRefs.tokval(res) == testname1

    ctx = BugRefs.ParseContext("$testname1:")
    res = BugRefs.parse_name!("$testname1:", ctx)
    print_errors(ctx)
    @test length(ctx.errors) < 1
    @test ctx.line == 1 && ctx.col == length(testname1) + 1
    @test BugRefs.tokval(res) == testname1
    
    ctx = BugRefs.ParseContext(text_simple)
    res = BugRefs.parse_name_or_bugref!(text_simple, ctx)
    print_errors(ctx)
    @test isa(res, BugRefs.TestName)
    @test BugRefs.tokval(res) == testname1

    BugRefs.iterate!(text_simple, ctx)
    res = BugRefs.parse_name_or_bugref!(text_simple, ctx)
    print_errors(ctx)
    @test isa(res, BugRefs.BugRef)
    @test BugRefs.tokval(res) == bugref1

    (taggings, ctx) = parse_comment(text_messy)
    print_errors(ctx)
    @test length(taggings) == 1
    @test BugRefs.tokval(taggings[1].test) == testname1
    @test BugRefs.tokval(taggings[1].ref) == bugref1

    (taggings, ctx) = parse_comment(many_to_many)
    print_errors(ctx)
    @test length(taggings) == 1
    @test BugRefs.tokval(taggings[1].test) == testname2
    @test BugRefs.tokval(taggings[1].tests[1]) == testname3
    @test BugRefs.tokval(taggings[1].ref) == bugref1
    @test BugRefs.tokval(taggings[1].refs[1]) == bugref2

    (taggings, ctx) = parse_comment(many_spaces)
    print_errors(ctx)
    @test length(taggings) == 1
    @test BugRefs.tokval(taggings[1].test) == testname2
    @test BugRefs.tokval(taggings[1].tests[1]) == testname3
    @test BugRefs.tokval(taggings[1].ref) == bugref1
    @test BugRefs.tokval(taggings[1].refs[1]) == bugref2

    (taggings, ctx) = parse_comment(many_to_many2)
    print_errors(ctx)
    @test length(taggings) == 2
    @test BugRefs.tokval(taggings[1].test) == testname1
    @test BugRefs.tokval(taggings[1].tests[1]) == testname2
    @test BugRefs.tokval(taggings[1].tests[2]) == testname3
    @test BugRefs.tokval(taggings[1].ref) == bugref1
    @test BugRefs.tokval(taggings[2].test) == testname2
    @test BugRefs.tokval(taggings[2].ref) == bugref2

    (taggings, ctx) = parse_comment(naked_bugrefs)
    print_errors(ctx)
    @test length(taggings) == 2
    @test taggings[1].test == BugRefs.WILDCARD
    @test BugRefs.tokval(taggings[1].ref) == bugref1
    @test taggings[2].test == BugRefs.WILDCARD
    @test BugRefs.tokval(taggings[2].ref) == bugref2

    println("Benchmarking:")
    btexts = [text_messy, many_to_many, many_spaces, many_to_many2, naked_bugrefs]
    for t in btexts
        @time parse_comment(t)
    end
end
