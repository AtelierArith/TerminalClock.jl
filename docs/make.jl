using TerminalClock
using Documenter

DocMeta.setdocmeta!(
    TerminalClock,
    :DocTestSetup,
    :(using TerminalClock);
    recursive=true,
)

makedocs(;
    modules=[TerminalClock],
    authors="Satoshi Terasaki <terasakisatoshi.math@gmail.com> and contributors",
    repo="https://github.com/AtelierArith/TerminalClock.jl/blob/{commit}{path}#{line}",
    sitename="TerminalClock.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://atelierarith.github.io/TerminalClock.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/AtelierArith/TerminalClock.jl",
    devbranch="main",
)
