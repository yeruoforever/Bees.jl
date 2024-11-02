using Test

using Bees
using Bees.Types: ToolDefinition, Message
using Bees.APIs
using OpenAI: OpenAIProvider

local_host = true

if local_host
    @testset "OpenAI API" verbose = true begin
        @testset "list models" begin
            provider = OpenAIProvider(
                api_key="NO_API_KEY",
                base_url="http://192.168.192.253:23333/v1"
            )
            list_models(provider)
            @test true
        end

        @testset "completions" begin
            provider = OpenAIProvider(
                api_key="NO_API_KEY",
                base_url="http://192.168.192.253:23333/v1"
            )
            models = list_models(provider)
            if !isempty(models)
                model_id = models[1].id
                msg = Message(content="hello", sender="Test")
                res = completions(provider, model_id, [msg])
                m = res.choices[1].message
                m |> dump
            end
            @test true
        end
    end
end

if local_host
    @testset verbose = true "Inspiration" begin
        @testset "OpenAI" begin
            provider = OpenAIProvider(
                api_key="NO_API_KEY",
                base_url="http://192.168.192.253:23333/v1"
            )
            model_id = list_models(provider)[1].id
            inspiration = InspirationOpenAI(provider, model_id)
            msg = Message(content="hello", sender="Test")
            plan = completions(inspiration, [msg])
            @test plan.describe != ""
        end
    end
end

@testset verbose = true "Tools" begin
    @testset "function defination" begin
        "this is a test function"
        @juliatool function tttest()
            "there are some result"
        end
        res = convert(ToolDefinition, tttest)
        @test res.name == "tttest"
        @test res.description == "this is a test function"
        @test isempty(res.parameters.properties)

        "this is a test function"
        @juliatool function tttest1(;
            a::Integer=1,
            b::String="hello")
            "there are some result"
        end
        res = convert(ToolDefinition, tttest1)
        @test res.name == "tttest1"
        @test res.description == "this is a test function"
        for p in res.parameters.properties
            if p.name == :a
                @test p.type == Integer
                @test p.description == ""
            elseif p.name == :b
                @test p.type == String
                @test p.description == ""
            end
        end

        "this is a test function"
        @juliatool function tttest2(;
            a::Integer=desc"this is the test parameter a",
            b::String="hello" ↦ "this is the test parameter b"
        )
            "there are some result"
        end
        res = convert(ToolDefinition, tttest2)
        @test res.name == "tttest2"
        @test res.description == "this is a test function"
        for p in res.parameters.properties
            if p.name == :a
                @test p.type == Integer
                @test p.description == "this is the test parameter a"
            elseif p.name == :b
                @test p.type == String
                @test p.description == "this is the test parameter b"
            end
        end

        "this is a test function"
        @juliatool function tttest3(
            x, y=desc"this y",
            z="hello" ↦ "this is z",
            a::Integer=desc"this is the test parameter a",
            b::String="hello" ↦ "this is the test parameter b"
        )
            "there are some result"
        end
        res = convert(ToolDefinition, tttest3)
        @test res.name == "tttest3"
        @test res.description == "this is a test function"
        for p in res.parameters.properties
            if p.name == :x
                @test p.type == Any
                @test p.description == ""
            elseif p.name == :y
                @test p.type == Any
                @test p.description == "this y"
            elseif p.name == :z
                @test p.type == Any
                @test p.description == "this is z"
            elseif p.name == :a
                @test p.type == Integer
                @test p.description == "this is the test parameter a"
            elseif p.name == :b
                @test p.type == String
                @test p.description == "this is the test parameter b"
            end
        end
    end

    @testset "struction defination" begin
        "this is the test struct"
        struct T1
            "this is a"
            a::Integer
            "this is b"
            b::String
        end
        @test_throws ArgumentError convert(ToolDefinition, T1)
        "this is the test struct"
        struct T2 <: AbstractTool
            "this is a"
            a::Integer
            "this is b"
            b::String
        end
        res = convert(ToolDefinition, T2)
        @test res.name == "T2"
        @test res.description == "this is the test struct"
        for p in res.parameters.properties
            if p.name == :a
                @test p.type == Integer
                @test p.description == "this is a"
            elseif p.name == :b
                @test p.type == String
                @test p.description == "this is b"
            end
        end

        "this is the test struct"
        @kwdef struct T3 <: AbstractTool
            a::Integer = 10
            "this is b"
            b::String = "666"
        end
        res = convert(ToolDefinition, T3)
        @test res.name == "T3"
        @test res.description == "this is the test struct"
        for p in res.parameters.properties
            if p.name == :a
                @test p.type == Integer
                @test p.description == ""
            elseif p.name == :b
                @test p.type == String
                @test p.description == "this is b"
            end
        end
    end
end

if local_host
    @testset "Swarm" verbose = true begin
        provider = OpenAIProvider(
            api_key="NO_API_KEY",
            base_url="http://192.168.192.253:23333/v1"
        )
        model_id = list_models(provider)[1].id
        inspiration = InspirationOpenAI(provider, model_id)

        @testset "bare minimum" begin
            bee = Bee(
                "Bee",
                inspiration,
                "help others",
                Function[],
                Dict{Symbol,Any}()
            )
            swarm = Swarm(target="kindly friends", status=Dict{Symbol,Any}())
            for m in start!(swarm, bee)
                println(m)
            end
        end

        @testset "weather bot" begin

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

            bot = Bee(
                name="Weather Bee",
                inspiration=inspiration,
                tools=[get_weather, send_email]
            )

            swarm = Swarm(
                target="Send an email to `Bob` with the weather details for `New York`.",
                status=Dict{Symbol,Any}()
            )

            for m in start!(swarm, bot)
                println(m)
            end
        end
    end
end
