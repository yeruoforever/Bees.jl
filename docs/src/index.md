# Bees.jl

*A simple multi-agent framework in julia.*

- **Design Agent Tools in julia way**
- **Interactive Data Analysis Dashboard (Coming soon)**
- **Predefined Prompt (Coming soon)**

The porpose of `Bees`  is to introduce agent into scientific computing and realize the full automation of data processing, analysis, visualization and other functions.

It is designed to be simple and easy to use, while still being flexible enough to handle a wide range of multi-agent problems.

## Usage


### Define the tools in julia way

```julia
using Bees

"""Get the current weather in a given location. Location MUST be a city."""
@juliatool function get_weather(;
    location::String=desc"the location to get the weather for.",
    time::String="now" ↦ "the time to get the weather for, default is `now`,format is `YYYY-MM-DD`."
)
    @info "Getting the weather..."
    """{"location":$(location), "temp": 65, "unit": "F","time": $(time)"}"""
end

"""Send an email to a recipient with a subject and body."""
@juliatool function send_email(;
    recipient::String=desc"the name of the recipient.",
    subject::String=desc"the subject of the email.",
    body::String=desc"the body of the email."
)
    @info """Sending email...
    To: $(recipient)
    Subject: $(subject)
    Body: $(body)"""
    "Email sent!"
end
```

### Create a Bee and a Swarm

```julia

provider = OpenAIProvider(
    api_key="YOUR_API_KEY",
    base_url="http://<YOUR LLM Service URL>/v1"
)
model_id = list_models(provider)[1].id
inspiration = InspirationOpenAI(provider, model_id)

bot = Bee(
    name="Weather Bee",
    inspiration=inspiration,
    tools=[get_weather, send_email]
)

swarm = Swarm(
    target="Send an email to `Bob` with the weather details for `New York`.",
    status=Dict{Symbol,Any}()
)
```
### Start the Swarm and see what happens

```julia
for m in start!(swarm, bot)
    println(m)
end

```

```shell
[ Info: Getting the weather...

┌ Info: Sending email...
│ To: Bob
│ Subject: Weather in New York
└ Body: The current temperature in New York is 65°F.
```

```shell
[2024-11-02T17:28:26.879][✓][Beekeeper]:
  Send an email to Bob with the weather details for New York.
[2024-11-02T17:28:29.126][✓][Weather Bee]:
  To send an email to Bob with the weather details for New York, I need to perform the following steps:

    1. Get the current weather in New York.

    2. Compose an email with the weather details.

    3. Send the email to Bob.

  Let's start by getting the current weather in New York.
[2024-11-02T17:28:29.463][✓][Weather Bee]:
  {"location":New York, "temp": 65, "unit": "F","time": now"}
[2024-11-02T17:28:31.134][✓][Weather Bee]:
  The current temperature in New York is 65°F. Now, I will compose an email with this information and send it to Bob.
[2024-11-02T17:28:31.159][✓][Weather Bee]:
  Email sent!
[2024-11-02T17:28:31.587][✓][Weather Bee]:
  Email sent to Bob with the weather details for New York.
```


## Installation

```julia
] add Bees
```


## Julia Function Call

Currently, we support two formats of the tool defination:

- Callable Struct as a subtype of `AbstractTool`
- Function with `@juliatool`

### Callable Struct

This is the native way to creata a callable object with complete annotation,
for example, the description, the parameters and the reminders.
But you must define object as the subtype of `AbstractTool`
and define the <parameters> and the <function body> separately.
```julia
"Get the current temperature for a specific location"
@kwdef struct GetCurrentTemperature <: AbstractTool
    "The city and state, e.g., San Francisco, CA"
    city::String = "San Francisco, CA"
    """The temperature unit to use.
    Infer this from the user's location.
    select from `Celsius` and `Fahrenheit`
    """
    unit::String = "Fahrenheit"
end

function (args::GetCurrentTemperature)()
    (; city, unit) = args
    t = rand(-20:30)
    if unit == "Celsius"
        "The current temperature in $city is $(t)°C."
    else
        "The current temperature in $city is $(t+32)°F."
    end
end

"Get the probability of rain for a specific location"
@kwdef struct GetRainProbability <: AbstractTool
    "The city and state, e.g., San Francisco, CA"
    location::String = "San Francisco, CA"
end

function (args::GetRainProbability)()
    (; location) = args
    p = rand(Float32)
    "The probability of rain in $location is $(p*100)%."
end
```

### Function with `@juliatool`

This is a more convenient way to define a tool.
You can just add `@juliatool` macro before the function definition.
```julia
"add 1 to the `x`"
function my_add(x::Integer)
    x + 1
end

"add 1 to the `x`"
@juliatool function my_add(x::Integer)
    x + 1
end
```
You can call the tool with keyword arguments,
because `@juliatool` will automatically convert the function to keyword formation: `my_add(; x::Integer)`.
It is a true function, which you can call or export.
```julia
my_add(x=1)
typeof(my_add) <: Function # true
```


The `@juliatool` macro allows you to add descriptions to the function's parameters.

- The best way to declare the parameters is to use the `v::T = "default" ↦ "the description."`,
  `↦` is a symbol which is used to separate the default value and the parameter's description,
  which could be typed by `\mapsto<tab>` in julia REPL.

- You can also declare the parameters without default value
  and provide the description like `v::T = desc"the description."`,
  which `desc"..."` is meant that `"..."` is the description of the parameter
  rather than the default value.

- Though the type, default value and description of the parameter is optional,
  you would better to provide them, because it's helpful for LLM to understand the
  parameters and the function.

```julia
"Get the current temperature for a specific location"
@juliatool function get_current_temperature(;
    city::String="Beijing" ↦ "The city and state, e.g., San Francisco, CA",
    unit::String="Celsius" ↦ """The temperature unit to use.
    Infer this from the user's location.
    select from `Celsius` and `Fahrenheit`
    """
)
    t = rand(-20:30)
    if unit == "Celsius"
        "The current temperature in $city is $(t)°C."
    else
        "The current temperature in $city is $(t+32)°F."
    end
end

"Get the probability of rain for a specific location"
@juliatool function get_rain_probability(;
    location::String="Beijing" ↦ "The city and state, e.g., San Francisco, CA"
)
    p = rand(Float32)
    "The probability of rain in $location is $(p*100)%."
end
```

### Transfer the session to other bee

When current bee can't handle the task, it can transfer the session to other bee.
A transfer can be defined as a function which returns a `Bee`.

```julia
"transfer the session to the email bee"
@juliatool function transfer_to_email()
    Bee(name="Email Bee")
end
```

### Memory of Bee and the State of Swarm

A bee can remember the usable information in the session and the swarm can keep the state of the session.

```julia
bee = Bee(name="Weather Bee", memory=Dict(:location => "New York", :temp => 65, :unit => "F"))
swarm = Swarm(name="Send the emails", state=Dict(:who => "Bob", :address => "Bob@Home"))
```

### Read the memory and the state

A bee's **memory** can be helpful when using the tool,
and a bee should have the ability to get the **status** of the swarm.
Two special parameters, `__memory__` and `__status__`,
are used to achieve this.

```julia
"send a email with the weather details"
@juliatool function send_weather_email(;
    __memory__, __status__
)
    location = __memory__[:location]
    temp = __memory__[:temp]
    unit = __memory__[:unit]
    """
    TO: $(__status__[:who])
    SUBJECT: Weather Details about $(location)
    BODY:
        The current temperature in $(location) is $(temp)°$(unit).
        Have a nice day!
    """
end
```

### Set the memory and Change the status

The memory and the status are mutable, so you can change them in the function.
In some cases, the bee would encounter an error, it's dangerous to change the memory and the status directly.
In fact, the `__memory__` and the `__status__` are the copys of the memory and the status,
so some runtime error would not affect the memory and the status.

If you want to change the memory and the status,
you can use the `Result` type to return the new memory and the new status.
The memory and status only update when the tool return successfully.

```julia
"set a+3 to the memory"
@juliatool function set_memory(;
    __memory__::Dict{Symbol,Any}
)
    v = __memory__[:a] + 3
    Result(value=v, memory=Dict(:a => v))
end

"set b+4 to status and set c to 0"
@juliatool function set_status(;
    __status__::Dict{Symbol,Any}
)
    v = __status__[:b] + 4
    Result(value=v, status=Dict(:b => v, :c => 0))
end

plan = Plan(describe="test plan", tools=[
    ToolCall(name="set_memory", args="""{}"""),
    ToolCall(name="set_status", args="""{}""")
])

messages, bees = do_things!(plan, bee, swarm)

for m in messages
    println(m)
end

bee.memory[:a] == 3
swarm.status[:b] == 3
swarm.status[:c] == 0
```

### All together

The  `Result` type allows a single tool invocation to modify memory, set status, and switch Bees!

```julia
@kwdef struct Result{T}
    value::Optional{T} = nothing
    flag::StatusType = Status.success
    bee::Optional{Bee} = nothing
    status::Optional{Dict} = nothing
    memory::Optional{Dict} = nothing
end

```
