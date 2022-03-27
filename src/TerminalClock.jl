module TerminalClock

using Dates
using TOML

using Configurations
using Preferences

export clock, stopwatch, countdown

include("types.jl")

default_tomlfile() = joinpath(dirname(@__FILE__), "dials", "ASCII.toml")

function set_dials(tomlfile::AbstractString)
    @set_preferences!("tomlfile" => tomlfile)
    @info("New dials set; restart your Julia session for this change to take effect!")
end

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
    DomainError("n should satisfy 0≤ n ≤9, actual $n")
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
    for _ in 1:H
        clearline(move_up=true)
    end
end

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

function countdown(;
    hour=nothing::Optional,
    minute=nothing::Optional,
    second=nothing::Optional,
)
    countdown(setup_timer(; hour, minute, second))
end

function countdown(t::Time)
    while true
        try
            str = clock(t)
            println(str)
            sleep(1)
            if Dates.hour(t) == Dates.minute(t) == Dates.second(t) == 0
                break
            end
            t -= Second(1)
            H = length(split(str, "\n"))
            clearlines(H)
        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end

function stopwatch(duration=0.1::AbstractFloat)
    start = Dates.now()
    sleep(0.001) # warmup
    while true
        try
            Δ = Dates.now() - start # millisecond
            periods =
                Dates.canonicalize(Dates.CompoundPeriod(Dates.Millisecond(Δ))).periods
            str = stopwatch(Time(periods...))
            println(str)
            sleep(duration)
            H = length(split(str, "\n"))
            clearlines(H)
        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end

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
