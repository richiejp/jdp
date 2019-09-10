"""

Metarules are generic constraints which can be placed on an object to describe
how it relates to other objects. They have a textual representation and can be
embedded within any text so long as the surrounding text does not contain any
unmatched `[`.

"""
module Metarules

"A rule specifying a general constraint"
abstract type Rule end

"""Describes a comparison between a field's value in an object and the
specified value.

"""
struct Comparison <: Rule
    op::Symbol
    name::String
    value::Union{String, Int, Float64}

    Comparison(op, name, value::Symbol) =
        new(op, String(name), String(value))

    Comparison(op, name, value) =
        new(op, String(name), value)
end

const VALID_CALLS = [:(==), :(~)]

"Try to convert the Julia AST `expr` into rules"
function interpret!(rules::Vector{Rule}, expr::Expr)
    expr.head == :vect || return
    isempty(expr.args) && return

    for rule in expr.args
        rule isa Expr || continue

        head = rule.head
        args = rule.args

        is_valid_call = head == :call &&
            length(args) == 3 &&
            args[1] in VALID_CALLS &&
            args[2] isa Union{Symbol, String} &&
            args[3] isa Union{Symbol, String, Int, Float64}

        if is_valid_call
            push!(rules, Comparison(args[1], args[2], args[3]))
            continue
        end

        is_valid_assign = head == :(=) &&
            length(args) == 2 &&
            args[1] isa Union{Symbol, String} &&
            args[2] isa Union{Symbol, String, Int, Float64}

        if is_valid_assign
            push!(rules, Comparison(:(==), args[1], args[2]))
        end
    end
end

"""Try to extract a vector of rules from `text`

Returns an empty vector if unsuccessful.
"""
function extract(text)::Vector{Rule}
    rules = Rule[]
    i = nextind(text, 0)

    while i < sizeof(text)
        if text[i] == '['
            (expr, j) = Meta.parse(text, i; raise=false, greedy=false)

            interpret!(rules, expr)

            i = j - 1
        end

        i = nextind(text, i)
    end

    rules
end

end
