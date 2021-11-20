# TerminalClock.jl

[![CI](https://github.com/AtelierArith/TerminalClock.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AtelierArith/TerminalClock.jl/actions/workflows/CI.yml)

Display Clock on your Terminal

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

1. Prepare "MyDials.toml" e.g. [src/dials/UnicodeBox.toml](./src/dials/UnicodeBox.toml)
  - See [Issue 16](https://github.com/AtelierArith/TerminalClock.jl/issues/16)
2. After that do the following command on your Julia REPL:

```julia
julia> ENV["TERMINAL_CLOCK_TOML"] = abspath("path/to/MyDials.toml")
julia> using Pkg; Pkg.build("TerminalClock")
```
