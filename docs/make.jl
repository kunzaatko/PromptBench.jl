using PromptBench
using Documenter

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
