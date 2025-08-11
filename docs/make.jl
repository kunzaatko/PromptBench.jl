using PromptBench

links = InterLinks(
    "Julia" => "https://docs.julialang.org/en/v1/",
    "Satisfiability" => "https://elsoroka.github.io/Satisfiability.jl/dev/"
)

DocMeta.setdocmeta!(PromptBench, :DocTestSetup, :(using PromptBench); recursive=true)

makedocs(;
    modules=[PromptBench],
    authors="Martin Kunz <martinkunz@email.cz> and contributors",
    sitename="PromptBench.jl",
    format=Documenter.HTML(;
        canonical="https://kunzaatko.github.io/PromptBench.jl",
        edit_link="trunk",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/kunzaatko/PromptBench.jl",
    devbranch="trunk",
)
