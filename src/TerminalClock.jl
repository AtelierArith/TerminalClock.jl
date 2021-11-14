module TerminalClock
using Dates

export displayclock

include("types.jl")
include("dials.jl")
include("mediumdials.jl")
include("smalldials.jl")

n2d(n) = N2D[n]
n2d(n, s::Symbol) = n2d(n, Val(s))
n2d(n, sz::Val{:normal}) = N2D[n]
n2d(n, sz::Val{:medium}) = MEDIUMN2D[n]
n2d(n, sz::Val{:small}) = SMALLN2D[n]

function clean(H)
    buf = IOBuffer()
    for i in 1:H
        print(buf, "\x1b[2K") # clear line
        print(buf, "\x1b[999D\x1b[$(1)A") # rollback
    end
    print(buf |> take! |> String)
end

function createclock(dt=Dates.now())
    buf = IOBuffer()
    h = hour(dt)
    m = minute(dt)
    s = second(dt)
    h1, h2 = n2d.(divrem(h, 10))
    m1, m2 = n2d.(divrem(m, 10))
    s1, s2 = n2d.(divrem(s, 10))
    str = hcat(h1, h2, colon, m1, m2, colon, s1, s2).str
    print(buf, str)
    return buf |> take! |> String
end

function displayclock()
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
    ms3 = n2d.(ms3_, :small)
    ms1, ms2 = n2d.(divrem(ms12, 10), :small)

    str = hcat(m1, m2, colon, s1, s2, smallcolon, ms1, ms2, ms3).str
    print(buf, str)
    return buf |> take! |> String
end

function stopwatch(duration=0.1)
    start = Dates.now()
    sleep(0.001) # warmup
    while true
        try
            Δ = Dates.now() - start # millisecond
            periods = Dates.canonicalize(Dates.CompoundPeriod(Dates.Millisecond(Δ))).periods
            str = stopwatch(Time(periods...))
            println(str)
            sleep(duration)
            H = length(split(str, "\n"))
            clean(H)

        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end
            sleep(0.5)
            H = length(split(str, "\n"))
            clean(H)
        catch e
            isa(e, InterruptException) || error(e)
            break
        end
    end
end

end # module
