module Metarules

abstract type Rule end

struct Comparison <: Rule
    op::Symbol
    name::String
    value::String
end

Comparison(op, name, value) = Comparison(op, String(name), String(value))

const VALID_CALLS = [:(==), :(~)]

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
            args[3] isa Union{Symbol, String}

        if is_valid_call
            push!(rules, Comparison(args[1], args[2], args[3]))
            continue
        end

        is_valid_assign = head == :(=) &&
            length(args) == 2 &&
            args[1] isa Union{Symbol, String} &&
            args[2] isa Union{Symbol, String}

        if is_valid_assign
            push!(rules, Comparison(:(==), args[1], args[2]))
        end
    end
end

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
