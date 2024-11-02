module Tool

using Markdown: parse as md_parse
using ..Meta: setfuncmeta!
using ..Types: Parameter, ToolParameters, ToolDefinition

"""declare description string using desc"..."""
macro desc_str(exp)
    md_parse(exp)
end

"""a tool function to provide the syntax sugar for combine the default value and the description.
Return the default value.
"""
↦(a, _) = a


function param_desc(p::Symbol)
    (name=p, type=missing, value=missing, desc=missing)
end

function param_desc(p::Expr)
    if p.head == :(::)
        (name=p.args[1], type=p.args[2], value=missing, desc=missing)
    elseif p.head == :kw # a[::T] = v [↦ "description"]
        k = p.args[1]
        v = p.args[2]
        sub = param_desc(k)
        if v isa Expr
            # a[::T] = v [↦ "description"]
            if v.head == :call && v.args[1] == :(↦)
                (name=sub.name, type=sub.type, value=v.args[2], desc=v.args[3])
                # a[::T] = desc"description"
            elseif v.head == :macrocall && v.args[1] == Symbol("@desc_str")
                (name=sub.name, type=sub.type, value=missing, desc=p.args[2].args[3])
            else #
                @error "Invalid parameter definition."
                sub
            end
        else
            (name=sub.name, type=sub.type, value=v, desc=missing)
        end
    else
        throw(ArgumentError("Invalid parameter definition."))
    end
end

"define a function as LLM function"
macro juliatool(exp)
    if exp.head == :function
        calls = exp.args[1]
        block = exp.args[2]
        if calls.head != :call
            throw(ArgumentError("Invalid function definition."))
        end
        name = calls.args[1]
        ps = []
        need_convert = false
        for each in calls.args[2:end]
            if each isa Expr && each.head == :parameters
                for p in each.args
                    push!(ps, param_desc(p))
                end
            else
                push!(ps, param_desc(each))
                need_convert = true
            end
        end
        need_convert && @warn "Need to convert the function to full Keyword Arguments Function."
    end
    ptvs = map(ps) do p
        if ismissing(p.type)
            @warn "Type not specified for parameter $(p.name)"
            t = :Any
        else
            t = p.type
        end

        if ismissing(p.value)
            Expr(:(::), p.name, t)
        else
            Expr(:kw, Expr(:(::), p.name, t), p.value)
        end
    end
    pl = Parameter[]
    for p in ps
        push!(
            pl,
            Parameter(
                p.name,
                ismissing(p.desc) ? "" : p.desc,
                ismissing(p.type) ? Any : eval(p.type),
            )
        )
    end
    fps = ToolParameters(
        properties=pl,
        required=map(p -> p.name, filter(p -> ismissing(p.value), ps))
    )
    setfuncmeta!(__module__, name, fps)
    kwfunc = Expr(:function, Expr(:call, name, Expr(:parameters, ptvs...)), block)
    esc(Core.@__doc__ kwfunc)
end

export @juliatool, @desc_str, ↦

end
