module Types

using ...TypeAlias: Optional

using JSON3: Object

@kwdef struct Model
    id::String
    created::Integer
    owned_by::String
end

@kwdef struct ChatFunction
    arguments::String
    name::String
end

@kwdef struct ChatCompletionMessageToolCall
    id::String
    f::ChatFunction # 'function' is a reserved word in Julia'
end

@kwdef struct ChoiceDeltaFunctionCall
    arguments::Optional{String} = nothing
    name::Optional{String} = nothing
end

@kwdef struct ChoiceDeltaToolCallFunction
    arguments::Optional{String} = nothing
    name::Optional{String} = nothing
end

@kwdef struct ChoiceDeltaToolCall
    id::Optional{String} = nothing
    index::Integer
    f::Optional{ChoiceDeltaToolCallFunction} = nothing # 'function' is a reserved word in Julia'
end

@kwdef struct ChoiceDelta
    content::Optional{String} = nothing
    function_call::Optional{ChoiceDeltaFunctionCall} = nothing
    refusal::Optional{String} = nothing
    role::Optional{String} = nothing
    tool_calls::Optional{Vector{ChoiceDeltaToolCall}} = nothing
end

@kwdef struct TopLogprob
    token::String
    logprob::Float64
    bytes::Optional{Vector{UInt8}} = nothing
end

@kwdef struct ChatCompletionTokenLogprob
    token::String
    bytes::Optional{Vector{UInt8}} = nothing
    logprob::Float64
    top_logprob::Vector{TopLogprob} = nothing
end

@kwdef struct ChoiceLogprobs
    content::Optional{Vector{ChatCompletionTokenLogprob}} = nothing
    refusal::Optional{Vector{ChatCompletionTokenLogprob}} = nothing
end

@kwdef struct ChoiceChunk
    index::Integer
    finish_reason::Optional{String} = nothing
    delta::ChoiceDelta
    logprobs::Optional{ChoiceLogprobs} = nothing
end

@kwdef struct CompletionTokensDetails
    audio_tokens::Optional{Integer} = nothing
    reasoning_tokens::Optional{Integer} = nothing
end

@kwdef struct PromptTokensDetails
    audio_tokens::Optional{Integer} = nothing
    cached_tokens::Optional{Integer} = nothing
end

@kwdef struct CompletionUsage
    completion_tokens::Integer
    prompt_tokens::Integer
    total_tokens::Integer
    completion_tokens_details::Optional{CompletionTokensDetails} = nothing
    prompt_tokens_details::Optional{PromptTokensDetails} = nothing
end

@kwdef struct ChatCompletionChunk
    id::String
    choices::Optional{Vector{ChoiceChunk}} = nothing
    created::Integer
    model::String
    object::String
    service_tier::Optional{String} = nothing
    system_fingerprint::Optional{String} = nothing
    usage::Optional{CompletionUsage} = nothing
end

@kwdef struct FunctionCall
    name::String
    arguments::String
end

@kwdef struct ChatCompletionMessage
    content::Optional{String} = nothing
    refusal::Optional{String} = nothing
    role::String = "assistant"
    function_call::Optional{FunctionCall} = nothing
    tool_calls::Optional{Vector{ChatCompletionMessageToolCall}} = nothing
end

@kwdef struct Choice
    finish_reason::String
    index::Integer
    logprobs::Optional{ChoiceLogprobs} = nothing
    message::ChatCompletionMessage
end

@kwdef struct ChatCompletion
    id::String
    choices::Vector{Choice}
    created::Integer
    model::String
    service_tier::Optional{String} = nothing # ["scale", "default"]
    system_fingerprint::Optional{String} = nothing
    usage::Optional{CompletionUsage} = nothing
end

export Model, ChatFunction, ChatCompletionMessageToolCall, ChoiceDeltaFunctionCall, ChoiceDeltaToolCallFunction, ChoiceDeltaToolCall, ChoiceDelta, TopLogprob, ChatCompletionTokenLogprob, ChoiceLogprobs, ChoiceChunk, CompletionTokensDetails, PromptTokensDetails, CompletionUsage, ChatCompletionChunk, FunctionCall, ChatCompletionMessage, Choice, ChatCompletion


convert_by_hand = Set{Symbol}([:ChatCompletionMessageToolCall, :ChoiceDeltaToolCall])

function Base.convert(::Type{ChatCompletionMessageToolCall}, x::Object)
    ChatCompletionMessageToolCall(id=x[:id], f=convert(ChatFunction, x[:function]))
end

function Base.convert(::Type{ChoiceDeltaToolCall}, x::Object)
    ChoiceDeltaToolCall(id=get(x, :id, nothing), index=x[:index], f=get(x, :function, nothing))
end


for name in names(Types)
    obj = getfield(Types, name)
    if isstructtype(obj) && name ∉ convert_by_hand
        @eval begin
            function Base.convert(::Type{$name}, x::Object)
                ps = Pair{Symbol,Any}[]
                for k in fieldnames($name)
                    v = get(x, k, nothing)
                    if !isnothing(v)
                        push!(ps, Symbol(k) => v)
                    end
                end
                return $name(; ps...)
            end
        end
    end
end

end
