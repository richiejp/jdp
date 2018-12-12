"Helpers for functional style programming"
module Functional

"""Curry

This allows partial function application by wrapping the passed function `f`
in two lambdas. This provides a limited form of Currying.

When a function is wrapped with `c` the first time you call it, it will return
a new function with the arguments you supplied already applied. So that

```
c(f) = f'
f'(a, b, ...) = f''
f''(u, v, ...) = f(a, b, ..., u, v, ...)
```

where "a, b, ..." and "u, v, ..." are lists of arbitrary variables.

## Examples

Classic currying example:

```
add(x, y) = x + y
add2(y) = c(add)(2)
```

This is useful when chaining operations due to limitations of the do-syntax
and the chain operator `|>`:

```
cmap = c(map)
cfilter = c(filter)

1:10 |> cmap() do x
    x^2
end |> cfilter() do x
    x > 50
end
```

Note that functions like `cmap` are generally already defined by this module.
"""
c(f) = (a...) -> (b...) -> f(a..., b...)

"Backwards Curry"
bc(f) = (a...) -> (b...) -> f(b..., a...)

cmap = c(map)
cforeach = c(foreach)
cifilter = c(Iterators.filter)
cfilter = c(filter)

"""Do fn(val) if cond(val) else nothing

If the condition is true then returns the result of fn(val) otherwise returns 
nothing. This can be chained with `cdefault` to provide a default value when
cond(val) is false.
"""
doif(fn::Function, cond::Function, val) = if cond(val)
    fn(val)
else
    nothing
end

cdoif = c(doif)

default(::Nothing, def) = def
default(val, _) = val
cdefault = bc(default)

end
