using OpenAI: OpenAIProvider, openai_request
using JSON3: Object

include("types.jl")

using .Types: ChatCompletionChunk, ChatCompletionMessage, ChatCompletion, Choice, Model, ChatFunction
using ..Bees.Types: Message, ToolCall
using ..Bees.Role

"""
Lists the currently available models,
and provides basic information about each one such as the owner and availability.

[OpenAI API](https://platform.openai.com/docs/api-reference/models/list)
"""
function list_models(provider::OpenAIProvider)::Vector{Model}
    res = openai_request("models", provider; method="GET", http_kwargs=NamedTuple())
    res.response[:data]
end

"""Combine chunks into a single completion. """
function combine(cs::Vector{ChatCompletionChunk})
    @warn "Be careful with this function, it may not be correct for all cases"
    # length(cs) == 0 && return ChatCompletion()
    contents = map(chunk -> chunk.choices[1].delta.content, cs)
    role = cs[1].choices[1].delta.role
    text = join(contents, "")
    msg = ChatCompletionMessage(content=text, role=Symbol(role))
    choice = Choice(cs[end].choices[1].finish_reason, 0, nothing, msg)
    ChatCompletion(id=cs[1].id, created=cs[1].created, model=cs[1].model, choices=[choice])
end

function delta_content(c::ChatCompletionChunk)
    c.choices[1].delta.content
end

function delta_content(::Nothing)
    "\n"
end


"""
Creates a model response for the given chat conversation.

[OpenAI API](https://platform.openai.com/docs/api-reference/chat/create)
"""
function completions(
    provider::OpenAIProvider,
    model::String,
    messages::Vector{Message};
    http_kwargs::NamedTuple=NamedTuple(),
    streamcallback=nothing,
    kwargs...
)::ChatCompletion
    if isnothing(streamcallback)
        r = openai_request(
            "chat/completions", provider;
            method="POST",
            model=model,
            messages=messages,
            http_kwargs=http_kwargs,
            streamcallback=nothing,
            kwargs...
        )
        r.response
    else
        chunks = ChatCompletionChunk[]
        hook = x -> begin
            # `data: <json...>``
            #        ^^^^^^^^^
            if x[7:end] != "[DONE]"
                chunk = convert(ChatCompletionChunk, js_read(x[7:end]))
                push!(chunks, chunk)
                streamcallback(chunk)
            end
        end
        openai_request(
            "chat/completions", provider;
            method="POST",
            model=model,
            messages=messages,
            http_kwargs=http_kwargs,
            streamcallback=hook,
            kwargs...
        )
        streamcallback(nothing)
        combine(chunks)
    end
end

function Base.convert(::Type{ToolCall}, f::ChatFunction)
    ToolCall(name=f.name, args=f.arguments)
end

function Base.convert(::Type{Plan}, m::ChatCompletionMessage)
    tools = isnothing(m.tool_calls) ? [] : map(x -> x.f, m.tool_calls)
    Plan(describe=m.content, tools=tools)
end

function Base.convert(::Type{Plan}, m::ChatCompletion)
    m.choices[1].message
end
