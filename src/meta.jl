module Meta

using Markdown: parse as md_parse, term as md_show
using Documenter.DocSystem: getdocs


"The unique `Symbol` that is used to store the function dictionary in each module."
const TOOL_META = gensym(:funcmeta)
"List of modules that have the function dictionary added."
const TOOL_META_MODULE = Module[]


"Initialize the function meta data for the module `m`."
function initfuncdesc!(m::Module)
    if !isdefined(m, TOOL_META)
        @debug "Initializing function meta data for module $m"
        Core.eval(m, :(const $TOOL_META = Dict{Symbol,Any}()))
        push!(TOOL_META_MODULE, m)
    else
        @warn "Function meta data already initialized for module $m"
    end
    getfield(m, TOOL_META)
end


getfuncmeta(m::Module) = isdefined(m, TOOL_META) ? getfield(m, TOOL_META) : initfuncdesc!(m)
getfuncmeta(m::Module, f::Symbol, default=nothing) = get(getfuncmeta(m), f, default)

function setfuncmeta!(m::Module, f::Symbol, x)
    isdefined(m, TOOL_META) || initfuncdesc!(m)
    meta = getfuncmeta(m)
    haskey(meta, f) && @warn "$f already set for module $m, overwriting..."
    meta[f] = x
end

function check_and_getdoc(f)
    docs = getdocs(f)
    if isempty(docs)
        @warn "no docs found for $f"
    elseif length(docs) != 1
        @warn "multiple docs found for $f, using the first one."
    end
    first(docs)
end

tool_desc(::Type{String}) = "string"
tool_desc(::Type{Integer}) = "integer"
tool_desc(::Type{AbstractFloat}) = "number"
tool_desc(::Type{Bool}) = "boolean"
tool_desc(::Type{Array}) = "array"
tool_desc(::Type{Dict}) = "object"

function describe(f::Function)
    doc = check_and_getdoc(f)
    m = doc.data[:module]
    info = getfuncmeta(m, Symbol(f), nothing)
    isnothing(info) && throw(ArgumentError("No function meta data found for `$f` in module `$m`, do you forget to use `@juliatool`?"))
    doc, info
end

end
