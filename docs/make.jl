using Documenter, Bees

_pages = [
    "Bees.jl" => [
        "Home" => "index.md",
        # "Manual" =>  "guide.md",
        # "Examples" => "examples.md",
        "Reference" => "ref.md"
    ]
]

makedocs(
    pages=_pages,
    sitename="Bees",
    remotes=nothing
)
