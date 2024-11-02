module Types

using Dates
using Markdown: parse as md_parse, term as md_show
using Documenter.DocSystem: getdocs

using ..Role
using ..Status
using ..TypeAlias
using ..Meta: describe


"records of the diligent work of bees"
@kwdef struct Message
    time::DateTime = now()
    role::RoleType = Role.system
    content::String
    sender::String
    status::StatusType = Status.success
end

@kwdef struct ToolCall
    name::String
    args::String
end

@kwdef struct Plan
    describe::String
    tools::Vector{ToolCall} = ToolCall[]
end

@kwdef struct Parameter
    name::Symbol
    description::String
    type::Type
    # enum::Optional{Array{Any}} = nothing
end

"A struct for handling a list of parameters."
@kwdef struct ToolParameters
    properties::Vector{Parameter} = Parameter[]
    required::Vector{Symbol} = Symbol[]
    strict::Bool = true
end

Base.haskey(fp::ToolParameters, k::Symbol) = any(p -> p.name == k, fp.properties)
Base.haskey(fp::ToolParameters, k::String) = haskey(fp, Symbol(k))

"delete the parameter which name is `k` from the function parameters."
function Base.delete!(fp::ToolParameters, k::Symbol)
    filter!(p -> p.name != k, fp.properties)
    filter!(r -> r != k, fp.required)
end
Base.delete!(fp::ToolParameters, k::String) = delete!(fp, Symbol(k))


"The description of a function call definition."
@kwdef struct ToolDefinition
    name::String
    description::String
    parameters::ToolParameters
    strict::Optional{Bool} = true
end

abstract type AbstractTool end

function Base.convert(::Type{ToolDefinition}, object::Type)
    object <: AbstractTool || throw(ArgumentError("object($object) should be a subtype of `AbstractTool`."))
    docs = getdocs(object)
    ps = Parameter[]
    length(docs) != 1 && @warn "multiple docs found for $object, using the first one."
    doc = first(docs)
    for (k, v) in get(doc.data, :fields, [])
        push!(ps, Parameter(name=k, description=v, type=fieldtype(object, k)))
    end
    ToolDefinition(
        name=string(object),
        description=doc.text[1],
        parameters=ToolParameters(properties=ps, required=[p.name for p in ps])
    )
end

function Base.convert(::Type{ToolDefinition}, f::Function)
    desc, ps = describe(f)
    ToolDefinition(
        name=string(f),
        description=desc.text[1],
        parameters=deepcopy(ps), # incase of modification of the original parameters
    )
end

function Base.show(io::IO, m::Message)
    print(io, "\e[1;69m[$(m.time)]\e[0")
    if m.role == Role.user
        print(io, "\e[1;34m")
    elseif m.role == Role.system
        print(io, "\e[1;32m")
    elseif m.role == Role.assistant
        print(io, "\e[1;36m")
    elseif m.role == Role.tool
        print(io, "\e[1;33m")
    end
    flag = m.status == Status.success ? "✓" : "✕"
    println(io, "[$flag][", m.sender, "]:\e[0m")
    md_show(io, md_parse(m.content))
end

abstract type AbstractInspiration end

"bees, equal by birth, but different by duty."
@kwdef struct Bee{T<:AbstractInspiration}
    name::String = "Agent"
    inspiration::T
    duty::Union{Function,String} = "You are helpful and good at using the provided tools to assist the user."
    tools::Vector{Function} = Function[]
    memory::Dict{Symbol,Any} = Dict{Symbol,Any}()
end

@kwdef struct Result{T}
    value::Optional{T} = nothing
    flag::StatusType = Status.success
    bee::Optional{Bee} = nothing
    status::Optional{Dict{Symbol,Any}} = nothing
    memory::Optional{Dict{Symbol,Any}} = nothing
end

"the swarm."
@kwdef struct Swarm{S}
    target::Union{Function,String}
    status::S
    history::Vector{Message} = Message[]
end

export ToolCall, ToolParameters, ToolDefinition, AbstractTool
export Message, Plan, Bee, Swarm, Result, AbstractInspiration

end
