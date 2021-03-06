testname1 = "a_Test-name12"
testname2 = "mmap07"
testname3 = "btrfs_0209"
bugref1 = "bsc#1984"
bugref2 = "git#abcdef1234567890"
bugref3 = "poo#234553"
text_simple = "$testname1:$bugref1"
text_messy = "Some jibba jabba before a bugref. $testname1: $bugref1"
many_to_many = "$testname2, $testname3 : $bugref1, $bugref2"
many_spaces = "$testname2 , $testname3 : $bugref1 , $bugref2"
many_to_many2 = "$testname1, $testname2, $testname3: $bugref1, $testname2: $bugref2"
naked_bugrefs = "$bugref1, $bugref2"
naked_bugrefs2 = "$bugref1, $bugref3"
naked_bugrefs3 = "$bugref1 $bugref3"
anti_bugref = "$testname1:! $bugref1"
propagated = "This is an automated message from the [JDP Propagate Bug Tags](https://rpalethorpe.io.suse.de/jdp/reports/Propagate%20Bug%20Tags.html) report\n\nThe following bug tags have been propagated: \n\n- `preadv203_64`: poo#53759 [**P3 - Normal** New: [kernel][ltp] Investigate preadv203 failures]\n    + From [LTP:syscalls:preadv203_64](https://openqa.suse.de/tests/3021740#step/preadv203_64/1) @ `sle-12-SP5-Server-DVD-ppc64le-Build0209-ltp_syscalls@ppc64le-virtio`\n- `fallocate05`: bsc#1099134 [**P3 - Medium** _Normal_ NEW: Btrfs fallocate PUNCH_HOLE | KEEP_SIZE fails on filled up FS on ppc64le]\n    + From [LTP:syscalls:fallocate05](https://openqa.suse.de/tests/2970184#step/fallocate05/1) @ `sle-12-SP5-Server-DVD-ppc64le-Build0197-ltp_syscalls@ppc64le-virtio`\n- `preadv203`: poo#53759 [**P3 - Normal** New: [kernel][ltp] Investigate preadv203 failures]\n    + From [LTP:syscalls:preadv203](https://openqa.suse.de/tests/3021740#step/preadv203/1) @ `sle-12-SP5-Server-DVD-ppc64le-Build0209-ltp_syscalls@ppc64le-virtio`\n- `copy_file_range02`: poo#55370 [**P3 - Normal** In Progress: [kernel][ltp][publiccloud] investigate copy_file_range02 failure]\n    + From [LTP:syscalls:copy_file_range02](https://openqa.suse.de/tests/3234220#step/copy_file_range02/1) @ `sle-12-SP5-Azure-Basic-On-Demand-x86_64-Build2.4-publiccloud_ltp_syscalls@az_Standard_A2_v2`\n"
advisory = replace(propagated, "#" => "@")
pvorel1 = """
if4-addr-change_ifconfig: poo#40400, if4-mtu-change_ip, f4-mtu-change_ifconfig: poo#40403

(Automatic takeover from t#2007414)
"""
pvorel2 = "Numa-testcases: bsc#1099878\n\n(Automatic takeover from t#2224950)\n"

print_errors(ctx::BugRefsParser.ParseContext) = if length(ctx.errors) > 0
    @debug "Parser errors: $ctx"
end

@testset "Bug Reference parsing" begin
    ctx = BugRefsParser.ParseContext("$testname1 ")
    res = BugRefsParser.parse_name!("$testname1 ", ctx, 1)
    print_errors(ctx)
    @test length(ctx.errors) < 1
    @test ctx.line == 1 && ctx.col == length(testname1) + 1
    @test BugRefsParser.tokval(res) == testname1

    ctx = BugRefsParser.ParseContext("$testname1:")
    res = BugRefsParser.parse_name!("$testname1:", ctx, 1)
    print_errors(ctx)
    @test length(ctx.errors) < 1
    @test ctx.line == 1 && ctx.col == length(testname1) + 1
    @test BugRefsParser.tokval(res) == testname1
    
    ctx = BugRefsParser.ParseContext(text_simple)
    res = BugRefsParser.parse_name_or_bugref!(text_simple, ctx)
    print_errors(ctx)
    @test isa(res, BugRefsParser.Test)
    @test BugRefsParser.tokval(res) == testname1

    BugRefsParser.iterate!(text_simple, ctx)
    res = BugRefsParser.parse_name_or_bugref!(text_simple, ctx)
    print_errors(ctx)
    @test isa(res, BugRefsParser.Ref)
    @test BugRefsParser.tokval(res) == bugref1

    (taggings, ctx) = parse_comment(text_messy)
    print_errors(ctx)
    @test length(taggings) == 1
    @test BugRefsParser.tokval(taggings[1].tests[1]) == testname1
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref1

    (taggings, ctx) = parse_comment(many_to_many)
    print_errors(ctx)
    @test length(taggings) == 1
    @test BugRefsParser.tokval(taggings[1].tests[1]) == testname3
    @test BugRefsParser.tokval(taggings[1].tests[2]) == testname2
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref2
    @test BugRefsParser.tokval(taggings[1].refs[2]) == bugref1

    (taggings, ctx) = parse_comment(many_spaces)
    print_errors(ctx)
    @test length(taggings) == 1
    @test BugRefsParser.tokval(taggings[1].tests[1]) == testname3
    @test BugRefsParser.tokval(taggings[1].tests[2]) == testname2
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref2
    @test BugRefsParser.tokval(taggings[1].refs[2]) == bugref1

    (taggings, ctx) = parse_comment(many_to_many2)
    print_errors(ctx)
    @test length(taggings) == 2
    @test BugRefsParser.tokval(taggings[1].tests[1]) == testname2
    @test BugRefsParser.tokval(taggings[1].tests[2]) == testname3
    @test BugRefsParser.tokval(taggings[1].tests[3]) == testname1
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref1
    @test BugRefsParser.tokval(taggings[2].tests[1]) == testname2
    @test BugRefsParser.tokval(taggings[2].refs[1]) == bugref2

    (taggings, ctx) = parse_comment(naked_bugrefs)
    print_errors(ctx)
    @test length(taggings) == 2
    @test taggings[1].tests[1] == BugRefsParser.WILDCARD
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref1
    @test taggings[2].tests[1] == BugRefsParser.WILDCARD
    @test BugRefsParser.tokval(taggings[2].refs[1]) == bugref2

    (taggings, ctx) = parse_comment(naked_bugrefs2)
    print_errors(ctx)
    @test length(taggings) == 2
    @test taggings[1].tests[1] == BugRefsParser.WILDCARD
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref1
    @test taggings[2].tests[1] == BugRefsParser.WILDCARD
    @test BugRefsParser.tokval(taggings[2].refs[1]) == bugref3
    
    (taggings, ctx) = parse_comment(pvorel1)
    print_errors(ctx)
    @test length(taggings) == 3
    @test BugRefsParser.tokval(taggings[1].tests[1]) == "if4-addr-change_ifconfig"
    @test BugRefsParser.tokval(taggings[1].refs[1]) == "poo#40400"
    @test BugRefsParser.tokval(taggings[2].tests[1]) == "f4-mtu-change_ifconfig"
    @test BugRefsParser.tokval(taggings[2].tests[2]) == "if4-mtu-change_ip"
    @test BugRefsParser.tokval(taggings[2].refs[1]) == "poo#40403"
    @test taggings[3].tests[1] == BugRefsParser.WILDCARD
    @test BugRefsParser.tokval(taggings[3].refs[1]) == "t#2007414"

    (taggings, ctx) = parse_comment(pvorel2)
    print_errors(ctx)
    @test length(taggings) == 2
    @test BugRefsParser.tokval(taggings[1].tests[1]) == "Numa-testcases"
    @test BugRefsParser.tokval(taggings[1].refs[1]) == "bsc#1099878"
    @test taggings[1].negated == false

    (taggings, ctx) = parse_comment(anti_bugref)
    print_errors(ctx)
    @test BugRefsParser.tokval(taggings[1].tests[1]) == testname1
    @test BugRefsParser.tokval(taggings[1].refs[1]) == bugref1
    @test taggings[1].negated == true

    (taggings, ctx) = parse_comment(propagated)
    print_errors(ctx)
    @test length(taggings) == 4
    @test all(t -> !t.negated, taggings)
    @test all(t -> t.quoted, Iterators.flatten(t.tests for t in taggings))

    println("Benchmarking:")
    btexts = [text_messy, many_to_many, many_spaces, many_to_many2, naked_bugrefs]
    for t in btexts
        @time parse_comment(t)
    end
end

@testset "Bug reference structures" begin
    using JDP.Tracker
    using JDP.Templates
    import JDP.Tracker: StaticSession, Instance

    apis = Dict("foo" => Api{StaticSession}("Foo", template"/bar/{id}"))
    trackers = TrackerRepo(apis, Dict(
        "foo" => Instance{StaticSession}(apis["foo"], nothing,
                                        "foo", "https", "foo"),
        "bsc" => Instance("bsc"),
        "poo" => Instance("poo"),
        "t" => Instance("t")))
    bref(s) = BugRefs.Ref(s, trackers)
    
    tags = extract_tags!(BugRefs.Tags(), pvorel1, trackers)
    @test length(tags) == 4
    @test tags[BugRefs.WILDCARD] == [bref("t#2007414")]

    tags = extract_tags!(BugRefs.Tags(), anti_bugref, trackers)
    @test tags[testname1] == [BugRefs.Ref(bugref1, trackers, true, false)]

    tags = extract_tags!(BugRefs.Tags(), propagated, trackers)
    @test length(tags) == 4
    @test all(rf -> rf.propagated, Iterators.flatten(values(tags)))
    @test tags["preadv203_64"] == [BugRefs.Ref("poo#53759", trackers, false, true)]

    tags = extract_tags!(BugRefs.Tags(), advisory, trackers)
    @test length(tags) == 4
    @test all(rf -> rf.propagated, Iterators.flatten(values(tags)))
    @test tags["preadv203_64"] == [BugRefs.Ref("poo@53759", trackers, false, true)]

    ref = bref("foo#bar")
    @test ref.tracker.tla == "foo"
    @test ref.id == "bar"
    @test ref == bref("foo#bar")

    ref = bref("foo#baz")
    @test ref.tracker.tla == "foo"
    @test ref.id == "baz"
end
