testname1 = "a_Test-name12"
bugref1 = "bsc#1984"
text_simple = "$testname1:$bugref1"
text_messy = "Some jibba jabba before a bugref. $testname1: $bugref1"

ctx = BugRefs.ParseContext("$testname1 ")
res = BugRefs.parse_name!("$testname1 ", ctx)
if length(ctx.errors) > 0
    println("Test parse_name: $ctx")
end
@test length(ctx.errors) < 1
@test ctx.line === 1 && ctx.col === length(testname1) + 1
@test BugRefs.tokval(res) === testname1

ctx = BugRefs.ParseContext(text_simple)
res = BugRefs.parse_name_or_bugref!(text_simple, ctx)
if length(ctx.errors) > 0
    println("Test parse_name_or_bugref: $ctx")
end
@test isa(res, BugRefs.TestName)
@test BugRefs.tokval(res) === testname1

res = BugRefs.parse_name_or_bugref!(text_simple, ctx)
if length(ctx.errors) > 0
    println("Test parse_name_or_bugref: $ctx")
end
@test isa(res, BugRefs.BugRef)
@test BugRefs.tokval(res) === bugref1
