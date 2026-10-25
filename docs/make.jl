using TerminalClock
using Documenter
using Dates

DocMeta.setdocmeta!(
    TerminalClock,
    :DocTestSetup,
    :(using TerminalClock, Dates);
    recursive=true,
)

makedocs(;
    modules=[TerminalClock],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    repo=Documenter.Remotes.GitHub("AtelierArith", "TerminalClock.jl"),
    sitename="TerminalClock.jl",
    checkdocs=:exports,
    doctest=true,
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://atelierarith.github.io/TerminalClock.jl/dev/",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Using the clocks" => "usage.md",
        "Timer accuracy" => "accuracy.md",
        "Custom dials" => "dials.md",
        "API reference" => "api.md",
        "Development" => "development.md",
    ],
)

# Build locally without attempting deployment. CI retains Documenter's own
# branch/tag checks; pull requests build and doctest but do not publish.
if get(ENV, "GITHUB_ACTIONS", "false") == "true"
    deploydocs(;
        repo="github.com/AtelierArith/TerminalClock.jl",
        devbranch="main",
    )
end
