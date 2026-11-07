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
    TerminalClock.set_dials(tomlfiles::AbstractVector{<:AbstractString})

Save several TOML dial files as candidates, in order. From the first, the
first dial that fits the terminal is used. The bundled `Keycap.toml` and
`Text.toml` dials follow the registered ones. Use absolute paths and restart
Julia to load the new dials.
"""
function set_dials(tomlfiles::AbstractVector{<:AbstractString})
    @set_preferences!("tomlfiles" => String[tomlfiles...])
    @info("New dials set; restart your Julia session for this change to take effect!")
end

"""
    TerminalClock.clear_dials()

Clear the saved dial preferences (`tomlfile` and `tomlfiles`). Restart Julia to
load the bundled ASCII dials. This changes preferences for the active
environment, not the current display.
"""
function clear_dials()
    @set_preferences!("tomlfile" => nothing)
    @set_preferences!("tomlfiles" => nothing)
    @info("Dials cleared; restart your Julia session for this change to take effect!")
end

function load_dials()
    tomlfile = @load_preference("tomlfile", default_tomlfile())
    toml = tomlfile |> TOML.parsefile
    return toml
end

load_font(path::AbstractString) = Font(TOML.parsefile(path))

function load_fonts()::Vector{Font}
    files = String[@load_preference("tomlfiles", String[])...]
    fonts = if isempty(files)
        [Font(load_dials())]
    else
        Font[load_font(f) for f in files]
    end
    dir = joinpath(dirname(@__FILE__), "dials")
    push!(fonts, load_font(joinpath(dir, "Keycap.toml")))
    push!(fonts, load_font(joinpath(dir, "Text.toml")))
    return fonts
end

const FONTS = load_fonts()
const DIALS_LARGE = FONTS[1].large
const DIALS_SMALL = FONTS[1].small

"""
Return `(rows, cols)` of a frame, where `cols` is the widest line by display width.
"""
function framesize(frame::AbstractString)::Tuple{Int,Int}
    lines = split(frame, '\n')
    return (length(lines), maximum(_displaywidth, lines))
end

"""
Return the first font whose frame fits the terminal (`rows <= termrows - 1`
and `cols <= termcols`), or the last font if none fits. `frame` maps a `Font`
to a `String`.
"""
function select_font(fonts::AbstractVector{Font}, frame, termsize::Tuple{Int,Int})::Font
    for font in fonts
        rows, cols = framesize(frame(font))
        rows <= termsize[1] - 1 && cols <= termsize[2] && return font
    end
    return last(fonts)
end

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

# Clear the whole screen and home the cursor. Live displays assume a pane of
# their own, so there is no line-by-line bookkeeping to go wrong on resize.
const CLEAR_SCREEN = "\e[H\e[2J"

_live_frame(fonts, frame, termsize::Tuple{Int,Int})::String =
    frame(select_font(fonts, frame, termsize))

"""
    clock()
    clock(t::Dates.Time) -> String
    clock(dt::Dates.DateTime) -> String

Display the current local wall-clock time as `HH:MM:SS` until Ctrl+C.
The live display refreshes approximately every 0.5 seconds.

The live display clears the whole screen on every refresh, so run it in a pane
of its own. If the terminal is too small for the dial, it switches to the next
smaller candidate (down to plain text) automatically. The last frame stays on
screen after exit.

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

clock(t::Time) = clock_frame(FONTS[1], t)

function clock_frame(font::Font, t::Time)::String
    h1, h2 = n2d.(Ref(font.large), divrem(hour(t), 10))
    m1, m2 = n2d.(Ref(font.large), divrem(minute(t), 10))
    s1, s2 = n2d.(Ref(font.large), divrem(second(t), 10))
    c = colon(font.large)
    return _join(font.large.separator, h1, h2, c, m1, m2, c, s1, s2).str
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
stopwatch(t::Time) = stopwatch_frame(FONTS[1], t)

function stopwatch_frame(font::Font, t::Time)::String
    large, small = font.large, font.small
    m1, m2 = n2d.(Ref(large), divrem(minute(t), 10))
    s1, s2 = n2d.(Ref(large), divrem(second(t), 10))
    ms12, ms3_ = divrem(millisecond(t), 10)
    ms1, ms2 = n2d.(Ref(small), divrem(ms12, 10))
    ms3 = n2d(small, ms3_)
    return _join(large.separator, m1, m2, colon(large), s1, s2,
                 colon(small), ms1, ms2, ms3).str
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

The live display clears the whole screen on every refresh, so run it in a pane
of its own. If the terminal is too small for the dial, it switches to the next
smaller candidate (down to plain text) automatically. The last frame stays on
screen after exit.

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
function _countdown(t::Time; now_ns=time_ns, wait=sleep, io::IO=stdout,
                    fonts=FONTS, termsize=() -> displaysize(io),
                    clear=() -> print(io, CLEAR_SCREEN),
                    render=t -> println(io, _live_frame(
                        fonts, f -> clock_frame(f, t), termsize())))
    duration_ns = Dates.value(t)
    start = now_ns()
    try
        while true
            elapsed = now_ns() - start
            remaining = max(Int128(duration_ns) - Int128(elapsed), 0)
            seconds = cld(remaining, 1_000_000_000)
            shown = Time(0) + Second(seconds)
            clear()
            render(shown)
            remaining == 0 && break

            # Wake at the next display boundary, accounting for rendering time.
            boundary = duration_ns - (seconds - 1) * 1_000_000_000
            delay = max(Int128(boundary) - Int128(now_ns() - start), 0)
            delay > 0 && wait(Float64(delay) / 1e9)
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
                    io::IO=stdout, fonts=FONTS, termsize=() -> displaysize(io),
                    clear=() -> print(io, CLEAR_SCREEN),
                    render=t -> println(io, _live_frame(
                        fonts, f -> stopwatch_frame(f, t), termsize())))
    isfinite(duration) && duration > 0 ||
        throw(ArgumentError("refresh interval must be finite and positive"))
    interval_ns = max(round(Int128, duration * 1e9), 1)
    start = now_ns()
    try
        while true
            elapsed = now_ns() - start
            t = _elapsed_time(elapsed)::Time
            clear()
            render(t)
            # Schedule from the origin, so rendering and clearing do not add
            # to every refresh interval. Missed deadlines trigger a fresh frame.
            deadline = (fld(Int128(elapsed), interval_ns) + 1) * interval_ns
            delay = deadline - Int128(now_ns() - start)
            delay > 0 && wait(Float64(delay) / 1e9)
        end
    catch e
        e isa InterruptException || rethrow()
    end
    return nothing
end

stopwatch(duration::AbstractFloat=0.01) = _stopwatch(duration)

function _clock(; now=Dates.now, wait=sleep, io::IO=stdout, fonts=FONTS,
                termsize=() -> displaysize(io),
                clear=() -> print(io, CLEAR_SCREEN),
                render=t -> println(io, _live_frame(
                    fonts, f -> clock_frame(f, t), termsize())))
    try
        while true
            clear()
            render(Dates.Time(now()))
            wait(0.5)
        end
    catch e
        e isa InterruptException || rethrow()
    end
    return nothing
end

clock() = _clock()

end # module
