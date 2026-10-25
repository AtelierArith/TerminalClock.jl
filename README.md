# TerminalClock.jl

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://atelierarith.github.io/TerminalClock.jl/dev/)

[![CI](https://github.com/AtelierArith/TerminalClock.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AtelierArith/TerminalClock.jl/actions/workflows/CI.yml)

Display Clock on your Terminal

Read the [documentation](https://atelierarith.github.io/TerminalClock.jl/dev/)
for usage, timer accuracy, custom dials, API reference, and development instructions.

Supported Julia versions: 1.10 and the latest stable release.

<img src="readme_assets/clock.gif" width="400">

<img src="readme_assets/stopwatch.gif" width="400">

# Installation

```console
julia -e 'using Pkg; Pkg.add("TerminalClock")'
```

# Usage

## `clock()`

- Hey Julian! What time is it now ?

```julia
julia> using TerminalClock; clock() # Press Ctrl+C to quit
+-------+ +-------+           +-------+ +-------+           +-------+ +-------+
|       |         |                   |         |           |       |         |
|       |         |     ⊗             |         |     ⊗     |       |         |
|       |         |                   |         |           |       |         |
+       + +-------+           +-------+ +-------+           +       + +-------+
|       |         |                   |         |           |       |         |
|       |         |     ⊗             |         |     ⊗     |       |         |
|       |         |                   |         |           |       |         |
+-------+ +-------+           +-------+ +-------+           +-------+ +-------+
```

## `stopwatch()`

Elapsed time uses a monotonic clock. The default refresh interval is 0.01 seconds;
the visible frame stays unchanged between refreshes.

- On your mark, get set, go! 

```julia
julia> using TerminalClock; stopwatch() # Press Ctrl+C to quit
+-------+ +-------+           +-------+ +-------+
|       | |       |           |       |         |
|       | |       |     ⊗     |       |         |
|       | |       |           |       |         |
+       + +       +           +       + +-------+       +---+ +---+ +---+
|       | |       |           |       | |           ⊗   |     |   |     |
|       | |       |     ⊗     |       | |               +---+ +---+ +---+
|       | |       |           |       | |           ⊗       |     | |
+-------+ +-------+           +-------+ +-------+       +---+ +---+ +---+
```

## `countdown()`

- Would you like to try some Japanese instant noodles?

The countdown uses a monotonic clock to avoid accumulating rendering and sleep
delays. It displays remaining seconds rounded up and returns after displaying zero.
Terminal output and OS scheduling can delay the final update; this is not a real-time timer.

```julia
julia> using TerminalClock; countdown() # equivalent to `countdown(hour=0, minute=3, second=0)`
+-------+ +-------+           +-------+ +-------+           +-------+ +-------+
|       | |       |           |       |         |           |       | |       |
|       | |       |     ⊗     |       |         |     ⊗     |       | |       |
|       | |       |           |       |         |           |       | |       |
+       + +       +           +       + +-------+           +       + +       +
|       | |       |           |       |         |           |       | |       |
|       | |       |     ⊗     |       |         |     ⊗     |       | |       |
|       | |       |           |       |         |           |       | |       |
+-------+ +-------+           +-------+ +-------+           +-------+ +-------+
```

# Another option for dial?

1. Prepare "YourDials.toml" e.g. [src/dials/UnicodeBox.toml](./src/dials/UnicodeBox.toml).
  - See also [Issue 16](https://github.com/AtelierArith/TerminalClock.jl/issues/16).
2. After that do the following command on your Julia REPL:

```console
julia> using TerminalClock
julia> tomlfile = joinpath(dirname(pathof(TerminalClock)), "dials", "UnicodeBox.toml");
julia> TerminalClock.set_dials("/path/to/YourDials.toml")
[ Info: New dials set; restart your Julia session for this change to take effect!
```

For example:

```console
$ julia --quiet
julia> using TerminalClock
julia> tomlfile = joinpath(dirname(pathof(TerminalClock)), "dials", "UnicodeBox.toml");
julia> TerminalClock.set_dials(tomlfile)
[ Info: New dials set; restart your Julia session for this change to take effect!
julia> exit() # please restart julia
$ julia --quiet
julia> using TerminalClock, Dates
julia> dt = DateTime(2021, 11, 15, 12, 34, 56, 7);
julia> print(clock(dt))
    ░█     ░█████░             ░██████       ░██             ███████    █████  
   ███     ██   ██░    ▒█▒     ██   ███     ████     ▒█▒     ██        ██   ██ 
    ██          ██     ███           ██    ██ ██     ███    ▒██        ██      
    ██         ██      ▒█▒          ░█░   ██  ██     ▒█▒    ██        ██       
    ██        ██                 █████   ██   ██            ████████░ ████████ 
    ██       ██        ▒█▒          ░█░ ██    ██     ▒█▒           ██ ██     ██
    ██      ██         ███           ██ █████████    ███           ██ █       █
    ██     ██░         ▒█▒     ██    ██       ██     ▒█▒    ██     ██ ███   ███
   ████    ███████             ░██████        ██             ███████░   █████
julia> TerminalClock.clear_dials() # you can clear preferences from `YourDials`.
[ Info: Dials cleared; restart your Julia session for this change to take effect!
julia> exit()
$ julia --quiet
julia> using TerminalClock, Dates
julia> dt = DateTime(2021, 11, 15, 12, 34, 56, 7);
julia> print(clock(dt))
        + +-------+           +-------+ +       +           +-------+ +-------+
        |         |                   | |       |           |         |
        |         |     ⊗             | |       |     ⊗     |         |
        |         |                   | |       |           |         |
        + +-------+           +-------+ +-------+           +-------+ +-------+
        | |                           |         |                   | |       |
        | |             ⊗             |         |     ⊗             | |       |
        | |                           |         |                   | |       |
        + +-------+           +-------+         +           +-------+ +-------+
```

# Appendix

- [Julia Discourse](https://discourse.julialang.org/t/ann-terminalclock-jl/71650)
- [Zenn.dev (web post written in Japanese)](https://zenn.dev/terasakisatoshi/articles/4416c268ed966c)
To measure a real ten-minute countdown (with output sent to the null device), run
`julia --project test/countdown_accuracy.jl`. Normal unit tests simulate timing
delays without waiting ten minutes.

To compare stopwatch frames with real elapsed time for one minute, run
`julia --project test/stopwatch_accuracy.jl`. This measures frame generation;
terminal emulator output latency is additional.

To test the public APIs in a background Julia REPL, including pseudo-terminal
output, run these optional Linux/macOS tests:

```console
julia --project test/repl_accuracy.jl stopwatch 60
julia --project test/repl_accuracy.jl countdown 600
```

The script decodes the displayed digits and compares frame receipt times using a
monotonic clock. It reports final drift, frame stalls, and the age of the previous
stopwatch frame before each update. Measurements start at the first received
frame and exclude REPL startup. These tests require the default ASCII dials and
do not measure a GUI terminal emulator's display latency. CI runs two-second
smoke tests on Linux and macOS; Windows runs the unit, Aqua, and JET tests.
