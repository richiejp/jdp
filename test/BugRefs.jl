testname1 = "a_Test-name12"
bugref1 = "bsc#1984"
text1 = "Some jibba jabba before a bugref. $testname1: $bugref1"

ctx = BugRefs.ParseContext(testname1)
res = BugRefs.parse_name!(testname1, ctx)
if length(ctx.errors) > 0
    show(ctx)
end
@test length(ctx.errors) < 1
@test ctx.line === 1 && ctx.col === length(testname1)
@test res === testname1

