```@meta
CurrentModule = TerminalClock
```

# TerminalClock.jl

TerminalClock displays a clock, stopwatch, or countdown using large character
dials in a terminal. It supports Julia **1.10** and the **latest stable release**,
with automated tests on Linux, macOS, and Windows.

## Install

In the Julia package REPL (press `]`):

```julia
pkg> add TerminalClock
```

Or use:

```julia
using Pkg
Pkg.add("TerminalClock")
```

The latest development documentation describes `main`. A registry release may
not yet include these changes. To install the development version explicitly:

```julia
Pkg.add(url="https://github.com/AtelierArith/TerminalClock.jl", rev="main")
```

## Start a display

Run one of these commands in a terminal Julia REPL. Each command occupies the
REPL while it is running.

| Command | Display | Stop |
|:--|:--|:--|
| `clock()` | Current local time, `HH:MM:SS` | Ctrl+C |
| `stopwatch()` | Elapsed time, `MM:SS:mmm` | Ctrl+C |
| `countdown(minute=10)` | Remaining time, `HH:MM:SS` | Zero, or Ctrl+C |

```julia
using TerminalClock

clock()                 # Current local time
stopwatch()             # 10 ms refresh interval
countdown(minute=10)    # Ten-minute timer
```

Execute one display at a time. These examples are intentionally not executed by
the documentation builder: the clock and stopwatch run until interrupted.

## Render a single frame

The `Time`/`DateTime` clock methods and the `Time` stopwatch method return a
string. They do not start a live timer.

```@example home
using TerminalClock, Dates
print(clock(Time(12, 34, 56)))
```

Use these methods to include a frame in your own output. See
[Using the clocks](@ref using-clocks) for details.

## Where to go next

- [Using the clocks](@ref using-clocks): defaults, argument ranges, and terminal requirements.
- [Timer accuracy](@ref timer-accuracy): deadlines, rendering delay, and measured precision.
- [Custom dials](@ref custom-dials): bundled fonts and the TOML format.
- [API reference](@ref api-reference): callable functions and their return values.
- [Development](@ref development): tests, local documentation builds, and CI deployment.

The source and issue tracker are on
[GitHub](https://github.com/AtelierArith/TerminalClock.jl).
