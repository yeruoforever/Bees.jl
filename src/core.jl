function prepare_callable_call(obj::DataType)
    fields = fieldnames(obj)
    fields, fields, true
end

function prepare_call(obj::DataType)
    if obj <: AbstractTool
        prepare_callable_call(obj)
    else
        throw(ArgumentError("Unknown type for $obj."))
    end
end

function prepare_call(obj::Function)
    m = parentmodule(obj)
    fps = getfuncmeta(m, Symbol(obj))
    fields = map(x -> x.name, fps.properties)
    fields, fps.required, false
end

"Execute a function call with the given arguments and context variables."
function unsafe_call(obj, args::Dict, memory::Dict, status::Dict)
    fields, required, need_call = prepare_call(obj)
    ps = Expr[]
    for f in fields
        if haskey(args, f)
            push!(ps, Expr(:kw, f, args[f]))
        elseif f in required && f != :__context__
            throw(ArgumentError("Missing required parameter `$(f)` for function `$obj`."))
        elseif f in required && f != :__memory__
            throw(ArgumentError("Missing required parameter `$(f)` for function `$obj`."))
        end
    end
    :__memory__ in fields && push!(ps, Expr(:kw, :__memory__, memory))
    :__status__ in fields && push!(ps, Expr(:kw, :__status__, status))

    fc = Expr(
        :call,
        :($obj),
        Expr(:parameters, ps...)
    )
    need_call ? eval(fc)() : eval(fc)
end


"interpret the bee's duty"
function duty(bee::Bee)
    bee.duty isa Function ? bee.duty(bee) : bee.duty
end

function check_tools(bee::Bee)
    map(bee.tools) do tool
        convert(ToolDefinition, tool)
    end
end

function think_and_plan(bee::Bee, history::Vector{Message})::Plan
    tools = check_tools(bee)
    for tool in tools
        delete!(tool.parameters, :__status__)
        delete!(tool.parameters, :__memory__)
    end
    completions(bee.inspiration, history; tools)
end

function handle_result(v)
    Result(value=string(v))
end

function handle_result(v::Result)
    v
end

function handle_result(v::Nothing)
    Result(value="Done.")
end

function handle_result(bee::Bee)
    Result(value="Done. Next, it will be handled by $(bee.name).")
end

function handle_tool_call(tool, args::String, memory::Dict, status::Dict)
    memory = deepcopy(memory)
    status = deepcopy(status)
    try
        ps = js_read(args) |> Dict
        v = unsafe_call(tool, ps, memory, status)
        handle_result(v)
    catch e
        @error e
        Result(
            value="""You should read the error message and decide whether to try again: $(e)""",
            flag=Status.failure
        )
    end
end

function do_things!(plan::Plan, bee::Bee, swarm::Swarm)
    tool_list = Dict(string(tool) => tool for tool in bee.tools)
    candidate_bees = Bee[]
    messages = map(plan.tools) do tool
        if haskey(tool_list, tool.name)
            tool_obj = tool_list[tool.name]
            result = handle_tool_call(tool_obj, tool.args, bee.memory, swarm.status)
            if result.flag == Status.success
                !isnothing(result.memory) && merge!(bee.memory, result.memory)
                !isnothing(result.status) && merge!(swarm.status, result.status)
                !isnothing(result.bee) && push!(candidate_bees, result.bee)
            else
                @warn "Tool $(tool.name) failed."
            end
            Message(content=result.value, sender=bee.name, role=Role.tool, status=result.flag)
        else
            @warn "Tool $(tool.name) not found in $(bee.name)'s tool list."
            Message(
                content="Tool $(tool.name) not found in $(bee.name)'s tool list.",
                sender=bee.name,
                role=Role.tool,
                status=Status.failure
            )
        end
    end
    messages, candidate_bees
end

function start!(swarm::Swarm, bee::Bee; maxturns::Integer=1000)
    bee_now = bee
    cur = length(swarm.history)
    target = swarm.target isa Function ? swarm.target() : swarm.target
    push!(swarm.history, Message(content=target, sender="Beekeeper", role=Role.system))
    while length(swarm.history) - cur < maxturns
        plan = think_and_plan(bee_now, swarm.history)
        push!(swarm.history, Message(content=plan.describe, sender=bee_now.name, role=Role.assistant))
        if !isempty(plan.tools)
            messages, candidates = do_things!(plan, bee_now, swarm)
            push!(swarm.history, messages...)
            length(candidates) > 1 && @warn "only one bee can be returned as the next bee."
            length(candidates) == 1 && (bee_now = candidates[1])
        else
            break
        end
    end
    swarm.history[cur+1:end]
end
