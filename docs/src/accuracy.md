```@meta
CurrentModule = TerminalClock
```

# [Timer accuracy](@id timer-accuracy)

## Elapsed time and wall-clock time

`clock()` reads the local system clock. Its display can jump if the system time
changes.

`countdown()` and `stopwatch()` measure elapsed time with Julia's monotonic
`time_ns()`. They do not derive elapsed time by subtracting local calendar
timestamps. Ordinary wall-clock corrections therefore do not change the measured
duration. Timing while the computer is suspended depends on the operating system;
these timers are intended for an awake machine.

## How rendering delays are handled

A loop that renders, sleeps one second, and subtracts one second accumulates
rendering and scheduling overhead on every tick. TerminalClock instead
recalculates each frame from elapsed time:

- The countdown calculates how much time remains until its original deadline,
  rounds that amount up to whole seconds, and targets the next display boundary.
- The stopwatch targets refresh deadlines measured from its start. Formatting and
  output time reduce the next wait.
- If rendering misses a deadline, the next iteration samples the current elapsed
  time. It does not replay every missed frame.
- Line-clearing escape sequences are batched, and frame height is calculated once
  rather than formatting a second copy of every frame.

This prevents per-frame delay from accumulating into the timer's elapsed-time
calculation. It cannot guarantee when an OS schedules the process or when a
terminal emulator presents the output.

## Resolution is not screen accuracy

There are three different quantities:

| Quantity | Meaning |
|:--|:--|
| Display resolution | Seconds for countdown; milliseconds for stopwatch. |
| Refresh interval | The stopwatch defaults to 10 ms. A frame stays unchanged between updates. |
| Output/presentation latency | Time spent formatting, writing, scheduling, and displaying a frame. |

If a stopwatch frame says `00:10:000`, the same frame may still be on screen
several milliseconds later. A 10 ms refresh interval is a requested cadence,
not an upper bound on that delay. Under load, stalls can be longer.

The countdown may display zero a little after its deadline. It does not
intentionally finish early or wait an extra second after zero.

## Measurements

These are observations from one Linux / Julia 1.13.2 environment, not timing
guarantees for other machines. The REPL tests decode the printed digits and
timestamp receipt at a pseudo-terminal. Their origin is the **first received
frame**, excluding REPL startup and JIT work before that frame. They do not measure
a GUI terminal emulator's final presentation.

| Test | Observation |
|:--|:--|
| Ten-minute countdown in a REPL | 601 frames; `10:00` to `00:00` took 600.003098 s, about 3.10 ms longer than 600 s. |
| Approximately one-minute stopwatch in a REPL | 5,987 frames; final relative elapsed time 60.001278 s, final display 60.001 s; difference about 0.28 ms. |
| Maximum relative stopwatch frame error in that run | About 73.42 ms. |
| Maximum age of the preceding frame before an update | About 82.42 ms, including an observed stall. |
| Ten-minute countdown with null-device output | 600.002764 s, including frame generation and scheduling. |

A small final difference does not mean every intermediate frame was equally
fresh. The maximum-age measurement captures pauses that a final timestamp alone
would miss.

## Reproduce the checks

From a repository checkout, install the package dependencies first:

```sh
julia --project -e 'using Pkg; Pkg.instantiate()'
```

For an actual background Julia REPL on **Linux or macOS**, with the default
ASCII dials:

```sh
julia --project test/repl_accuracy.jl stopwatch 60
julia --project test/repl_accuracy.jl countdown 600
```

The Julia script opens a pseudo-terminal, waits for the child REPL prompt, runs
the public API, decodes each complete frame, and compares receipt timestamps.
Bounded POSIX polling allows timeout cleanup even when a child stalls.
The script terminates its own child REPL after collecting the required frames.

For frame-generation checks without a pseudo-terminal:

```sh
julia --project test/stopwatch_accuracy.jl
julia --project test/countdown_accuracy.jl
```

The first takes approximately one minute and the second ten minutes. The
countdown check writes to the null device. The stopwatch check formats each
frame and compares the displayed milliseconds with an independent time sample.

Normal unit tests simulate long durations and injected delays without waiting
ten minutes. CI also runs two-second REPL checks on Linux/macOS. See
[Development](@ref development) for the complete test matrix.
