"""Generic methods for lazily loaded items

This is a stub which may be expanded to contain things relating to lazy loading.
"""
module Lazy

"""Subtypes of this should merely be links to another type's instances

This is somewhat similar to a future in the base library. However, unlike
futures, there is presently no general implementation of a link. This allows
us to handle caching and serialisation in the way(s) we need for each type.

Also, a link structure *usually* just specifies the ID of some resource
instead of an operation to retrieve/generate that resource. The operation used
is decided by dispatching on that type. This makes them less general than a
future which stores the operation.
"""
abstract type AbstractLink end

"""Load the resource pointed to by a link

This should be implemented by subtypes of AbstractLink"""
function load(link::T) where T <: AbstractLink
    error("$T needs to implement Lazy.load")
end

end
