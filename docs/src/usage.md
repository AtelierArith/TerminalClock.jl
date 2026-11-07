```@meta
CurrentModule = TerminalClock
```

# [Using the clocks](@id using-clocks)

## Terminal requirements

Use a terminal with ANSI cursor movement and a monospace font. The live displays
clear the whole screen (`ESC[H ESC[2J`) before every refresh, so they are meant
for a pane or window of their own; anything else on that screen is erased. The
last frame stays on screen when you exit with Ctrl+C or the countdown ends. The bundled ASCII-style dials also use a Unicode
colon symbol, so UTF-8 support is useful.

Give the default clock/countdown at least **79 columns and 9 rows**; the default
stopwatch uses **73 columns and 9 rows**. Small panes are fine:
each refresh checks the terminal size and picks the first candidate dial that
fits (the default dial, then the Keycap dial, then plain text such as
`12:34:56`), so shrinking or enlarging the pane switches dials automatically.
Custom fonts may require different dimensions.

Run a single display at a time. Logging or printing from other tasks to the
same terminal can disrupt cursor placement. Captured output in notebooks and CI
logs may show escape sequences instead of an animation; use a single-frame
method for those environments.

## Clock

```julia
using TerminalClock
clock()
```

The clock displays the current local system time and refreshes about twice per
second. It follows system clock changes. Use the stopwatch for measuring elapsed
time.

A `DateTime` or `Time` argument produces a frame without waiting:

```jldoctest
julia> using TerminalClock, Dates

julia> clock(DateTime(2026, 1, 2, 12, 34, 56)) == clock(Time(12, 34, 56))
true

julia> clock(Time(12, 34, 56, 789)) == clock(Time(12, 34, 56))
true
```

## Stopwatch

```julia
stopwatch()       # Refresh every 0.01 seconds by default
stopwatch(0.05)   # Refresh every 0.05 seconds, reducing output work
```

The argument is a positive, finite floating-point number of seconds. It controls
the refresh interval, not the total run time. Press Ctrl+C to stop; the live
method returns `nothing`.

The display uses minute, second, and millisecond fields, `MM:SS:mmm`.
**The minute field wraps after 59**: the display does not show hours. Its three
millisecond digits do not imply a 1 ms screen refresh rate.

```jldoctest
julia> using TerminalClock, Dates

julia> stopwatch(Time(1, 2, 3, 456)) == stopwatch(Time(0, 2, 3, 456))
true
```

See [Timer accuracy](@ref timer-accuracy) for the distinction between elapsed
time, frame timing, and the visible age of a frame.

## Countdown

```julia
countdown()                      # Three minutes
countdown(minute=10)             # Ten minutes
countdown(second=5)              # Five seconds
countdown(hour=1, minute=30)     # One hour and thirty minutes
countdown(second=0)              # Display zero and return immediately
```

With no keywords the timer defaults to three minutes. Once any keyword is
supplied, omitted components are zero. Components are validated by `Dates.Time`:

| Component | Allowed range |
|:--|:--|
| `hour` | 0–23 |
| `minute` | 0–59 |
| `second` | 0–59 |

For example, use `countdown(hour=1)` for one hour; `countdown(minute=60)` is
invalid. The API represents durations shorter than 24 hours.

You can also supply a `Time`, interpreted as a duration since midnight:

```julia
using Dates
countdown(Time(0, 10))
countdown(Time(0, 0, 0, 500))     # Half a second
```

The display rounds remaining seconds up. A half-second timer initially displays
one second, then zero. The function returns `nothing` after the zero frame,
without sleeping for another second. Ctrl+C ends the timer early.

## Troubleshooting

| Symptom | What to check |
|:--|:--|
| Output looks small or plain | The pane is too small for the large dial; enlarge it and the dial switches back on the next refresh. |
| Output flickers or other text disappears | The live display clears the whole screen; use a dedicated pane. |
| Cursor codes appear in a log | Render a single frame with `clock(t)` or `stopwatch(t)`. |
| Digits update in bursts | Reduce terminal load; a shorter interval cannot prevent OS or terminal stalls. |
| A saved custom dial fails to load | See [Recovering from a bad preference](@ref dial-recovery). |
