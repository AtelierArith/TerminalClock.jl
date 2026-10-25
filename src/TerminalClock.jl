module TerminalClock

using Dates
using TOML

using Configurations
using Preferences

export clock, stopwatch, countdown

include("types.jl")

default_tomlfile() = joinpath(dirname(@__FILE__), "dials", "ASCII.toml")

"""
    TerminalClock.set_dials(tomlfile::AbstractString)

Save the path to a TOML dial file in the active environment's preferences.
Use an absolute path and restart Julia to load the new dials. The file must
contain a complete `[Large]` table; `[Small]` is optional.

The file is loaded on the next import, so an invalid path or TOML file can
prevent `using TerminalClock`. See [Custom dials](@ref custom-dials).
"""
function set_dials(tomlfile::AbstractString)
    @set_preferences!("tomlfile" => tomlfile)
    @info("New dials set; restart your Julia session for this change to take effect!")
end

"""
    TerminalClock.clear_dials()

Clear the saved dial preference. Restart Julia to load the bundled ASCII dials.
This changes preferences for the active environment, not the current display.
"""
function clear_dials()
    @set_preferences!("tomlfile" => nothing)
    @info("Dials cleared; restart your Julia session for this change to take effect!")
end

function load_dials()
    tomlfile = @load_preference("tomlfile", default_tomlfile())
    toml = tomlfile |> TOML.parsefile
    return toml
end

const toml = load_dials()
const DIALS_LARGE = from_dict(Dials, toml["Large"])
const DIALS_SMALL = from_dict(Dials, get(toml, "Small", toml["Large"]))

colon(dial::Dials) = Dial(getfield(dial, :colon))

const COLON_LARGE = colon(DIALS_LARGE)
const COLON_SMALL = colon(DIALS_SMALL)

function n2d(dials::Dials, n::Int)
    n == 0 && return Dial(getfield(dials, :zero))
    n == 1 && return Dial(getfield(dials, :one))
    n == 2 && return Dial(getfield(dials, :two))
    n == 3 && return Dial(getfield(dials, :three))
    n == 4 && return Dial(getfield(dials, :four))
    n == 5 && return Dial(getfield(dials, :five))
    n == 6 && return Dial(getfield(dials, :six))
    n == 7 && return Dial(getfield(dials, :seven))
    n == 8 && return Dial(getfield(dials, :eight))
    n == 9 && return Dial(getfield(dials, :nine))
    throw(DomainError(n, "n should satisfy 0≤ n ≤9"))
end

n2d(n::Int, s::Symbol) = n2d(n, Val(s)) # symbol dispatcher
n2d(n::Int, ::Val{:Large}) = n2d(DIALS_LARGE, n)
n2d(n::Int, ::Val{:Small}) = n2d(DIALS_SMALL, n)
n2d(n::Int) = n2d(n, :Large)

function clearline(; move_up::Bool=false)
    buf = IOBuffer()
    print(buf, "\x1b[2K") # clear line
    print(buf, "\x1b[999D") # rollback the cursor
    move_up && print(buf, "\x1b[1A") # move up
    print(buf |> take! |> String)
end

function clearlines(H::Integer)
    # Send cursor movement in one write rather than one write per line.
    print(repeat("\x1b[2K\x1b[999D\x1b[1A", H))
end

"""
    clock()
    clock(t::Dates.Time) -> String
    clock(dt::Dates.DateTime) -> String

Display the current local wall-clock time as `HH:MM:SS` until Ctrl+C.
The live display refreshes approximately every 0.5 seconds.

Passing a `Time` or `DateTime` instead returns one dial frame without printing
or sleeping; the date and subsecond fields are ignored.

# Examples

```jldoctest
julia> using Dates

julia> clock(Time(12, 34, 56)) == clock(DateTime(2026, 1, 1, 12, 34, 56))
true
```
"""
clock(dt::DateTime) = clock(Time(dt))

function clock(t::Time)
    buf = IOBuffer()
    h = hour(t)
    m = minute(t)
    s = second(t)
    h1, h2 = n2d.(divrem(h, 10))
    m1, m2 = n2d.(divrem(m, 10))
    s1, s2 = n2d.(divrem(s, 10))
    str = hcat(h1, h2, COLON_LARGE, m1, m2, COLON_LARGE, s1, s2).str
    print(buf, str)
    return buf |> take! |> String
end

"""
    stopwatch(refresh_interval::AbstractFloat=0.01)
    stopwatch(t::Dates.Time) -> String

Display elapsed time as `MM:SS:mmm` until Ctrl+C. The interval is in seconds
and must be finite and positive. Elapsed time uses a monotonic clock, and
rendering time is deducted from the wait before the next refresh.

Passing a `Time` returns a single frame without printing or waiting.
Only its minute, second, and millisecond fields are shown: the visible minute
counter wraps after 59. Millisecond digits indicate resolution, not a guarantee
that the screen updates every millisecond. See [Timer accuracy](@ref timer-accuracy).

# Examples

```jldoctest
julia> using Dates

julia> stopwatch(Time(1, 2, 3, 456)) == stopwatch(Time(0, 2, 3, 456))
true
```
"""
function stopwatch(t::Time)
    buf = IOBuffer()
    h = hour(t)
    m = minute(t)
    s = second(t)
    ms = millisecond(t)
    h1, h2 = n2d.(divrem(h, 10))
    m1, m2 = n2d.(divrem(m, 10))
    s1, s2 = n2d.(divrem(s, 10))
    ms12, ms3_ = divrem(ms, 10)
    ms3 = n2d.(ms3_, :Small)
    ms1, ms2 = n2d.(divrem(ms12, 10), :Small)

    str = hcat(m1, m2, COLON_LARGE, s1, s2, COLON_SMALL, ms1, ms2, ms3).str
    print(buf, str)
    return buf |> take! |> String
end

const Optional = Union{Nothing,Int}

function setup_timer(;
    hour=nothing::Optional,
    minute=nothing::Optional,
    second=nothing::Optional,
)
    if all(isnothing.([hour, second, minute]))
        hour = 0
        minute = 3
        second = 0
    else
        hour = isnothing(hour) ? 0 : hour
        minute = isnothing(minute) ? 0 : minute
        second = isnothing(second) ? 0 : second
    end
    return Time(hour, minute, second)
end

"""
    countdown(; hour=nothing, minute=nothing, second=nothing)
    countdown(t::Dates.Time)

Run a countdown displaying `HH:MM:SS`, then return `nothing` after printing
zero. With no arguments, count down three minutes. If any keyword is supplied,
omitted components are zero. Components follow `Dates.Time` ranges:
hours 0–23, minutes 0–59, and seconds 0–59.

A `Time` is interpreted as a duration since midnight, including its subsecond
part. Remaining seconds are rounded up. A monotonic clock prevents rendering
and scheduler delays from accumulating; a slow terminal can delay an update.
There is no extra sleep after zero. Press Ctrl+C to stop early.

# Examples

These calls block while the timer runs:

```julia
countdown(minute=10)
countdown(hour=1, minute=30)
countdown(Dates.Time(0, 0, 0, 500)) # half a second
```
"""
function countdown(;
    hour=nothing::Optional,
    minute=nothing::Optional,
    second=nothing::Optional,
)
    countdown(setup_timer(; hour, minute, second))
end

# Keep time independently of rendering and scheduler delays. Injectable callbacks
# let tests exercise long durations and slow terminals without waiting in real time.
function _countdown(t::Time; now_ns=time_ns, wait=sleep,
                    render=t -> println(clock(t)), clear=clearlines)
    duration_ns = Dates.value(t)
    height = length(split(clock(t), "\n"))
    start = now_ns()
    try
        while true
            elapsed = now_ns() - start
            remaining = max(Int128(duration_ns) - Int128(elapsed), 0)
            seconds = cld(remaining, 1_000_000_000)
            shown = Time(0) + Second(seconds)
            render(shown)
            remaining == 0 && break

            # Wake at the next display boundary, accounting for rendering time.
            boundary = duration_ns - (seconds - 1) * 1_000_000_000
            delay = max(Int128(boundary) - Int128(now_ns() - start), 0)
            delay > 0 && wait(Float64(delay) / 1e9)
            clear(height)
        end
    catch e
        e isa InterruptException || rethrow()
    end
    return nothing
end

countdown(t::Time) = _countdown(t)

_elapsed_time(ns::Unsigned) =
    Time(0) + Nanosecond(Int64(ns % UInt64(86_400_000_000_000)))

function _stopwatch(duration::AbstractFloat; now_ns=time_ns, wait=sleep,
                    render=t -> println(stopwatch(t)), clear=clearlines)
    isfinite(duration) && duration > 0 ||
        throw(ArgumentError("refresh interval must be finite and positive"))
    height = length(split(stopwatch(Time(0)), "\n"))
    interval_ns = max(round(Int128, duration * 1e9), 1)
    start = now_ns()
    try
        while true
            elapsed = now_ns() - start
            t = _elapsed_time(elapsed)::Time
            render(t)
            # Schedule from the origin, so rendering and clearing do not add
            # to every refresh interval. Missed deadlines trigger a fresh frame.
            deadline = (fld(Int128(elapsed), interval_ns) + 1) * interval_ns
            delay = deadline - Int128(now_ns() - start)
            delay > 0 && wait(Float64(delay) / 1e9)
            clear(height)
        end
    catch e
        e isa InterruptException || rethrow()
    end
    return nothing
end

stopwatch(duration::AbstractFloat=0.01) = _stopwatch(duration)

function clock()
    while true
        try
            str = clock(Dates.now())
            println(str)
            sleep(0.5)
            H = length(split(str, "\n"))
            clearlines(H)
        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end

end # module
