module APIs

using Dates
using ..Role
using ..Status
using ..TypeAlias
using ..Types: Message, AbstractInspiration, Plan


include("wrapper/openai/api.jl")


function completions(
    ins::AbstractInspiration,
    messages::Vector{Message};
    http_kwargs::NamedTuple=NamedTuple(),
    streamcallback=nothing,
    kwargs...)::Plan
    throw(ErrorException("$ins Not implemented"))
end

@kwdef struct InspirationOpenAI <: AbstractInspiration
    provider::OpenAIProvider
    model::String
end

function completions(
    ins::InspirationOpenAI,
    messages::Vector{Message};
    http_kwargs::NamedTuple=NamedTuple(),
    streamcallback=nothing,
    kwargs...)::Plan

    if haskey(kwargs, :tools) && !isempty(kwargs[:tools])
        tools = kwargs[:tools]
        args = Dict{Symbol,Any}(k => v for (k, v) in kwargs)
        args[:tool_choice] = "auto"
        args[:parallel_tool_calls] = !isempty(tools)
        args[:tools] = map(x -> Dict(:function => x, :type => "function"), tools)
    else
        args = kwargs
    end

    convert(Plan, completions(ins.provider, ins.model, messages;
        http_kwargs=http_kwargs,
        streamcallback=streamcallback, args...
    ))
end

export AbstractInspiration, InspirationOpenAI, completions, list_models
export convert

end
