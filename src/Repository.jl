module Repository

export retrieve

"Some kind of item tracked by a tracker"
abstract type AbstractItem end

function retrieve(item::I,
                  in_container::C,
                  from::Union{String, Vector{String}};
                  kwargs...) where {I <: AbstractItem, C}
    error("Repository.fetch needs to be overriden for $I and $C")
end

end
