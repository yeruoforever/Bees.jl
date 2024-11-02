module Bees

include("typealias.jl")
include("role.jl")
include("status.jl")
include("meta.jl")
include("types.jl")
include("tool.jl")
include("api.jl")

using JSON3: read as js_read

using .Types: Message, Plan, Bee, Swarm, Role, Status, AbstractInspiration
using .Types: AbstractTool, ToolDefinition, ToolCall, Result
using .Tool
using .APIs
using .Meta: getfuncmeta
include("core.jl")

export ↦, @desc_str, @juliatool, AbstractTool
export Message, Plan, Bee, Swarm, Role, Status, AbstractInspiration, Result
export start!

end # module Bees
