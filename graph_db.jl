using LightGraphs, MetaGraphs

include("json.jl")

function intern_vert!(mg::MetaGraph, vtype::Symbol, name::String)
    try
        mg["$vtype $name", :index]
    catch
        if add_vertex!(mg, Dict(:name => name, :type => vtype))
            v = nv(mg)
            set_indexing_prop!(mg, v, :index, "$vtype $name")
            v
        else
            throw("Could not add $vtype vertex $name")
        end
    end
end

function add_machine!(mg::MetaGraph, m)
    mv = intern_vert!(mg, :machine, m["name"])

    for (k, v) in pairs(m["settings"])
        sv = intern_vert!(mg, :setting, k)
        add_edge!(mg, mv, sv, :value, v)
    end
end

function add_machines!(mg, ms)
    foreach(m -> add_machine!(mg, m), ms)
end

ms = flatten(get_machines()["Machines"])

mg = MetaGraph()
set_indexing_prop!(mg, :index)

add_machines!(mg, ms)

